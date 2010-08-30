;;; cucumber-i18n.el --- translate i18n keys inside cucumber features

;; Copyright (C) 2010 Yves Senn

;; Author: Yves Senn <yves.senn@gmail.com>
;; URL: http://www.emacswiki.org/emacs/CucumberI18nEl
;; Version: 0.1
;; Created: 30 August 2010
;; Keywords: ruby cucumber i18n rails
;; EmacsWiki: CucumberI18nEl

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; cucumber-i18n.el makes working with i18n keys inside your cucumber
;; scenarios less painless. It allows you to add overlays with the
;; matching translation for all the keys in the current buffer.

;; M-x cucumber-i18n-translate => adds the overlays
;; M-x cucumber-i18n-remove-translations => removes the overlays

;; you can also toggle between the overlay mode and the keys using:
;; M-x cucumber-i18n-toggle

;; currently cucumber-i18n relies on textmate.el to get the project
;; root of your application. If you don't use textmate.el just
;; overwrite the function 'cucumber-i18n--project-root' to fit your needs.

;;; Code:

(defvar *cucumber-i18n-process* nil)
(defvar *cucumber-i18n-translations* '())
(defvar *cucumber-i18n-process-name* "cucumber-i18n-translator")
(defvar *cucumber-i18n-process-buffer-name* "*cucumber-i18n-translator*")

(defcustom cucumber-i18n-locale
  "en"
  "this locale is used to translate the keys"
  :group 'cucumber-i18n
  :type 'string)

(defcustom cucumber-i18n-key-regexp
  "\\(key:\\([^\"|]+\\)\\)"
  "this regexp must match the key patter in your cucumber features.
the default pattern matches:
key:this.is.your.key"
  :group 'cucumber-i18n
  :type 'string)

(defun cucumber-i18n-change-locale (locale)
  (interactive "Mlanguage: ")
  (let ((active (cucumber-i18n--activated)))
    (cucumber-i18n-remove-translations)
    (setq cucumber-i18n-locale locale)
    (process-kill-without-query (get-buffer-process *cucumber-i18n-process-buffer-name*))
    (kill-buffer *cucumber-i18n-process-buffer-name*)
    (when active (cucumber-i18n-translate))))

(defun cucumber-i18n-toggle ()
  "toggle between translated overlays and i18n keys"
  (interactive)
  (if (cucumber-i18n--activated)
      (cucumber-i18n-remove-translations)
    (cucumber-i18n-translate)))

(defun cucumber-i18n-remove-translations ()
  "remove the translation overlays from the current buffer"
  (interactive)
  (when (cucumber-i18n--activated)
    (dolist (overlay *cucumber-i18n-translations*)
      (delete-overlay overlay)))
  (setq *cucumber-i18n-translations* '()))

(defun cucumber-i18n-translate ()
  "add overlays with the translation to the current buffer"
  (interactive)
  (cucumber-i18n-remove-translations)
  (save-excursion
    (beginning-of-buffer)
    (while (re-search-forward cucumber-i18n-key-regexp nil t)
      (let ((overlay (make-overlay (match-beginning 1)
                                   (match-end 1))))
        (overlay-put overlay 'display (cucumber-i18n--translate-key (replace-regexp-in-string "[ ]+$" "" (match-string 2))))
        (overlay-put overlay 'font-lock-face 'font-lock-doc-string-face)
        (add-to-list '*cucumber-i18n-translations* overlay)))))

(defun cucumber-i18n-replace-translations ()
  "replace all keys in the feature file with the matching translation.
This can be usefull when you move away from having keys in your cucumber features."
  (interactive)
  (cucumber-i18n-remove-translations)
  (save-excursion
    (beginning-of-buffer)
    (while (re-search-forward cucumber-i18n-key-regexp nil t)
      (replace-match (cucumber-i18n--translate-key (replace-regexp-in-string "[ ]+$" "" (match-string 2)))))))

(defun cucumber-i18n--activated ()
  *cucumber-i18n-translations*)

(defun cucumber-i18n--project-root ()
  (cond
   ((featurep 'textmate)
    (textmate-project-root))
   (t
    (message "cucumber-i18n currently depends on textmate.el"))))

(defun cucumber-i18n--translation-script ()
  (concat "cd " (cucumber-i18n--project-root) ";"
          "ruby -e "
          "\""
          "require 'rubygems';"
          "require 'active_support';"
          "RAILS_ROOT=File.dirname(__FILE__);"
          "I18n.load_path = Dir[File.join(RAILS_ROOT, 'config', 'locales', '" cucumber-i18n-locale "', '**', '*.{rb,yml,yaml}')];"
          "I18n.load_path += Dir[File.join(RAILS_ROOT, 'config', 'locales','" cucumber-i18n-locale ".{rb,yml,yaml}')];"
          "I18n.locale = :" cucumber-i18n-locale ";"
          "loop { puts I18n.t(gets.strip)};"
          "\""))

(defun cucumber-i18n--translate-key (key)
  (when (or (not *cucumber-i18n-process*)
            (not (equal (process-status *cucumber-i18n-process*) 'run)))
    (setq *cucumber-i18n-process* (start-process-shell-command *cucumber-i18n-process-name* *cucumber-i18n-process-buffer-name* (cucumber-i18n--translation-script))))
  (let ((output (process-buffer *cucumber-i18n-process*)))
    (save-excursion
      (set-buffer output)
      (kill-region (point-min) (point-max))
      (process-send-string *cucumber-i18n-process* (concat key "\n"))
      (accept-process-output *cucumber-i18n-process*)
      (replace-regexp-in-string "^\\s-*\\(.*?\\)\\s-*$" "\\1" (buffer-substring-no-properties (point-min) (point-max))))))

(provide 'cucumber-i18n)
;;; cucumber-i18n.el ends here
