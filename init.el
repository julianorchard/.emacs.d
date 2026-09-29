;;; init.el --- Emacs configuration file

;;; Commentary:

;; A fairly minimal Emacs config heavily inspired in layout (and choice for the nice-to-haves
;; I don't really care as much about) by https://github.com/Ronmi/emacs

;;; Code:

(let ((minver "29.1"))
  (when (version< emacs-version minver)
    (error "This Emacs config requires v%s or higher" minver)))

;; Bootstrap straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))
(setq package-enable-at-startup nil)
(setq-default straight-use-package-by-default t)
(if (fboundp 'straight-use-package)
    (straight-use-package 'use-package))

(when (eq system-type 'darwin)
  (dolist (path '("/opt/homebrew/bin" "/usr/local/bin"))
    (when (file-directory-p path)
      (add-to-list 'exec-path path)
      (setenv "PATH" (concat path path-separator (getenv "PATH")))))
  (let ((gnupg-home (expand-file-name "~/.config/gnupg")))
    (when (file-directory-p gnupg-home)
      (setenv "GNUPGHOME" gnupg-home)
      (setq epg-gpg-home-directory gnupg-home)))
  (when-let ((gpg (executable-find "gpg")))
    (setq epg-gpg-program gpg)))

(let ((path (expand-file-name "bin" user-emacs-directory)))
  (when (file-directory-p path)
    (add-to-list 'exec-path path)
    (setenv "PATH" (concat path path-separator (getenv "PATH")))))

(use-package vterm
  :commands (vterm vterm-other-window jdo/vterm-split)
  :defines
  tmux-mappings
  vterm-buffer-name
  vterm-eval-cmds
  vterm-keymap-exceptions
  vterm-mode-map
  vterm-max-scrollback
  :preface
  (defun jdo/current-directory ()
    "Return the most useful directory for commands started from this buffer."
    (cond
     (buffer-file-name
      (file-name-directory buffer-file-name))
     ((derived-mode-p 'dired-mode)
      default-directory)
     (t
      default-directory)))

  (defun jdo/vterm-split ()
    "Open or focus a vterm in a bottom split."
    (interactive)
    (let* ((dir (file-name-as-directory (expand-file-name (jdo/current-directory))))
           (buffer-name (format "*vterm: %s*" (abbreviate-file-name (directory-file-name dir))))
           (height (max 12 (floor (* (window-total-height) 0.3))))
           (buffer (get-buffer buffer-name))
           (window (or (and buffer (get-buffer-window buffer))
                       (split-window (selected-window) (- height) 'below))))
      (select-window window)
      (if (and buffer (buffer-live-p buffer))
          (switch-to-buffer buffer)
        (let ((default-directory dir))
          (vterm buffer-name)))
      (goto-char (point-max))
      (when (fboundp 'evil-insert-state)
        (evil-insert-state))))

  (defun jdo/vterm-bind-tmux-prefix ()
    "Keep the tmux-style prefix available inside vterm."
    (when (boundp 'vterm-mode-map)
      (keymap-set vterm-mode-map "C-a" tmux-mappings)
      (when (fboundp 'evil-define-key)
        (dolist (state '(insert normal motion visual emacs))
          (evil-define-key state vterm-mode-map
            (kbd "C-a") tmux-mappings)))
      (when (fboundp 'evil-collection-define-key)
        (dolist (state '(insert normal motion visual emacs))
          (evil-collection-define-key state 'vterm-mode-map
            (kbd "C-a") tmux-mappings)))))

  (defun jdo/vterm-bind-local-tmux-prefix ()
    "Keep the tmux-style prefix available in the current vterm buffer."
    (jdo/vterm-bind-tmux-prefix)
    (when (fboundp 'evil-local-set-key)
      (dolist (state '(insert normal motion visual emacs))
        (evil-local-set-key state (kbd "C-a") tmux-mappings))))

  (defun jdo/vterm-find-file-above (path)
    "Open PATH in an Emacs buffer above the current vterm window."
    (let* ((buffer (find-file-noselect path))
           (window (or (ignore-errors (windmove-find-other-window 'up))
                       (split-window (selected-window) nil 'above))))
      (select-window window)
      (switch-to-buffer buffer)))
  :init
  (setq vterm-keymap-exceptions
        '("C-a" "C-c" "C-x" "C-u" "C-g" "C-h" "C-l" "M-x" "M-o" "C-y" "M-y"))
  :custom
  (vterm-max-scrollback 10000)
  :config
  (jdo/vterm-bind-tmux-prefix)
  (with-eval-after-load 'evil
    (jdo/vterm-bind-tmux-prefix))
  (with-eval-after-load 'evil-collection-vterm
    (jdo/vterm-bind-tmux-prefix))
  (add-to-list 'vterm-eval-cmds '("find-file-above" jdo/vterm-find-file-above))
  (add-hook 'vterm-mode-hook #'jdo/vterm-bind-local-tmux-prefix))

(use-package emacs
  :defines display-line-numbers-type
  :init
  ;; Load times
  (setq gc-cons-percentage 0.6
        gc-cons-threshold most-positive-fixnum)
  (add-hook 'after-init-hook (lambda ()
                               (setq gc-cons-threshold 800000)))
  ;; Guff removal
  (menu-bar-mode -1)
  (scroll-bar-mode -1)
  (set-fringe-mode 5)
  (tool-bar-mode -1)
  (tooltip-mode -1)
  (display-fill-column-indicator-mode)
  (defalias 'yes-or-no-p 'y-or-n-p)
  ;; Escape escapes
  (global-set-key (kbd "<escape>") 'keyboard-escape-quit)
  ;; Line numbering plz
  (column-number-mode)
  (setq display-line-numbers-type 'relative)
  (dolist (mode '(text-mode-hook
                  prog-mode-hook
                  conf-mode-hook))
    (add-hook mode (lambda ()
		     (display-line-numbers-mode 1))))
  (dolist (rm-ln-hook '(org-mode-hook))
    (add-hook rm-ln-hook (lambda () (display-line-numbers-mode 0))))
  ;; I want to be completely transparent with you right now (I'm using Emacs 29.1+)
  (set-frame-parameter nil 'alpha-background 90)
  (add-to-list 'default-frame-alist '(alpha-background . 90))
  ;; ComicShanns
  (set-face-attribute 'default nil :font "ComicShannsMono Nerd Font Mono" :height 220 :weight 'normal)
  ;; Prot video on this was very helpful
  (setq display-buffer-alist
        '(
          ("\\*Warnings\\*"
           (display-buffer-reuse-mode-window display-buffer-below-selected)
           (dedicated . t)
           (window-height . fit-window-to-buffer)
           (window-parameters . ((mode-line-format . none))))
          ("\\*Org \\(Select\\|Note\\)\\*"
           (display-buffer-in-side-window)
           (dedicated . t)
           (side . bottom)
           (slot . 0)
           (window-parameters . ((mode-line-format . none))))
          ))
  ;; Set global EDE mode, see: https://www.gnu.org/software/emacs/manual/html_node/emacs/EDE.html
  (global-ede-mode t)
  :custom
  (indent-tabs-mode nil)
  (inhibit-startup-screen t)
  (make-backup-files nil)
  (size-indication-mode t)
  (smerge-refine-ignore-whitespace t))
(use-package paren
  :ensure nil
  :init
  (setq show-paren-delay 0)
  :config
  (show-paren-mode +1))
(use-package saveplace
  :hook (after-init . save-place-mode))
(use-package diminish)
(use-package ws-butler
  :diminish ws-butler-mode
  :functions ws-butler-mode
  :config (add-hook 'prog-mode-hook #'ws-butler-mode))
(use-package all-the-icons)
(use-package catppuccin-theme
  :defines catppuccin-flavor
  :config (setq catppuccin-flavor 'macchiato)
  :functions catppuccin-reload
  :config (catppuccin-reload))
(use-package nyan-mode
  :functions nyan-mode
  :config (nyan-mode))

;; Counsel == Consult
(use-package company
  :bind (:map prog-mode-map
              ("C-i" . company-indent-or-complete-common))
  :functions global-company-mode
  :config (global-company-mode t))
(use-package company-box
  :after (company all-the-icons)
  :diminish company-box-mode
  :hook (company-mode . company-box-mode)
  :defines company-box-icons-alist
  :init (setq company-box-icons-alist 'company-box-icons-all-the-icons))
(use-package consult-lsp)
(use-package consult
  :bind
  (("M-s r" . consult-ripgrep)))
(use-package consult-company)
(use-package magit
  :commands (magit-status magit-dispatch))
(use-package diff-hl
  :commands (global-diff-hl-mode diff-hl-dired-mode diff-hl-flydiff-mode diff-hl-magit-post-refresh)
  :hook ((after-init . global-diff-hl-mode)
         (dired-mode . diff-hl-dired-mode)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config
  (diff-hl-flydiff-mode 1))

;; Vertico == Ivy ??
(use-package vertico
  :ensure t
  ;; This is exactly how systemcrafters does it
  :bind (:map vertico-map
              ("C-j" . vertico-next)
              ("C-k" . vertico-previous))
  ;; :map minibuffer-local-map
  ;; ("M-h" . backward-kill-word))
  :custom (vertico-cycle t)
  :init (vertico-mode))
(use-package savehist
  :init (savehist-mode)
  :after vertico)
(use-package marginalia ;; Annotations for Vertico
  :functions marginalia-mode
  :config (marginalia-mode t)
  :after vertico)
(use-package all-the-icons-completion
  :after marginalia
  :functions all-the-icons-completion-mode
  :hook (marginalia-mode . all-the-icons-completion-marginalia-setup)
  :init (all-the-icons-completion-mode))
(use-package yasnippet
  :diminish yas-minor-mode
  :functions yas-reload-all
  :hook (prog-mode . yas-minor-mode)
  :config (yas-reload-all))
(use-package yasnippet-snippets
  :defer t
  :after yasnippet)

(use-package evil
  :after undo-fu
  :demand
  :defines
  evil-want-keybinding
  evil-want-integration
  evil-want-C-u-scroll
  evil-want-C-i-jump
  evil-undo-system
  evil-split-window-below
  evil-vsplit-window-right
  tmux-mappings
  :functions
  evil-mode
  evil-global-set-key
  evil-ex-define-cmd
  evil-define-key
  evil-set-leader
  jdo/dired-up-or-current-directory
  jdo/vterm-split
  magit-status
  :init
  (setq evil-want-keybinding nil)
  (setq evil-want-integration t)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-C-i-jump nil)
  (setq evil-undo-system 'undo-fu)
  :preface
  ;; From the yay-evil-emacs config:
  ;; https://github.com/ianyepan/yay-evil-emacs/blob/master/config.org#vi-keybindings
  (defun save-and-kill-this-buffer ()
    (interactive)
    (save-buffer)
    (kill-this-buffer))
  :config
  (evil-mode 1)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  (evil-global-set-key 'motion "j" 'evil-next-visual-line)
  (evil-global-set-key 'motion "k" 'evil-previous-visual-line)
  (evil-ex-define-cmd "q" #'kill-this-buffer)
  (evil-ex-define-cmd "wq" #'save-and-kill-this-buffer)
  ;; Custom tmux-like key maps
  (keymap-set global-map "C-a" tmux-mappings)
  ;; Vim Leader Mappings
  (evil-set-leader nil (kbd "SPC"))
  (evil-define-key 'normal 'global (kbd "<leader>ff") 'find-file)
  (evil-define-key 'normal 'global (kbd "<leader>gs") 'magit-status)
  (evil-define-key 'normal 'global (kbd "<leader>ts") 'jdo/vterm-split)
  (evil-define-key 'normal 'global (kbd "-") 'jdo/dired-up-or-current-directory)
  (evil-define-key 'normal 'global (kbd "<leader><leader>") 'list-buffers))
;; Org mappings (this is currently causing evil-mode to fuck up somehow)
(defvar-keymap tmux-org-mappings
  "a" 'org-agenda
  "c" 'org-capture)
;; Navigational mappings with Ctrl+A (as I have configured for Tmux)
;; These rely on Evil (see the line in evil above)
(defvar-keymap tmux-mappings
  "s" 'split-window-right
  "d" 'split-window-below
  "h" 'evil-window-left
  "k" 'evil-window-up
  "j" 'evil-window-down
  "l" 'evil-window-right
  "n" 'next-buffer
  "p" 'previous-buffer
  "r" 'eval-region
  "b" 'eval-buffer
  "!" 'delete-other-windows
  "q" 'delete-window
  "o" tmux-org-mappings)
(use-package evil-collection
  :after evil
  :diminish evil-collection-unimpaired-mode
  :functions evil-collection-init
  :config (evil-collection-init))
(use-package evil-commentary
  :after evil
  :functions evil-commentary-mode
  :config (evil-commentary-mode +1))
(use-package evil-surround
  :after evil
  :functions global-evil-surround-mode
  :config (global-evil-surround-mode 1))
(use-package undo-fu)

;; (use-package lsp-mode
;;   :hook
;;   ((
;;     dockerfile-mode
;;     go-mode
;;     json-mode
;;     markdown-mode+
;;     python-mode
;;     terraform-mode
;;     toml-mode
;;     typescript-mode
;;     yaml-mode
;;     ) . lsp-mode)
;;   :custom
;;   (lsp-dired-mode t)
;;   (lsp-eldoc-enable-hover t)
;;   (lsp-eldoc-render-all nil)
;;   (lsp-prefer-flymake nil)
;;   (lsp-signature-auto-activate
;;    '(:on-trigger-char :after-completion :on-server-request)))
;; (use-package lsp-docker)
;; (use-package dap-mode)
;; (use-package typescript-mode)
;; (use-package web-mode)
(use-package flycheck
  :functions global-flycheck-mode
  :init (global-flycheck-mode))
;; (use-package go-mode
;;   :custom
;;   (gofmt-command "goimports")
;;   (flycheck-go-gofmt-executable "goimports")
;;   (lsp-clients-go-server "gopls")
;;   (flycheck-go-vet-executable "go vet")
;;   (flycheck-go-vet-shadow t)
;;   (go-eldoc-gocode-args '("-cache"))
;;   (godoc-reuse-buffer t)
;;   :hook
;;   (before-save . gofmt-before-save))
;; (use-package yaml-mode)
;; (use-package toml-mode)
;; (use-package markdown-mode+)
;; (use-package markdown-preview-mode)
;; (use-package terraform-mode
;;   :defines terraform-format-on-save
;;   :init (setq terraform-format-on-save t))
;; (use-package hcl-mode)

(use-package terraform-mode
  :ensure t
  :custom
  (terraform-indent-level 4)
  (setq terraform-format-on-save))

(use-package dired
  :straight nil
  :ensure nil
  :commands (dired dired-jump jdo/dired-up-or-current-directory)
  :defines dired-mode-map
  :preface
  (defun jdo/dired-up-or-current-directory ()
    "Open Dired for this file's directory, or go up from Dired."
    (interactive)
    (if (derived-mode-p 'dired-mode)
        (dired-up-directory)
      (let ((file buffer-file-name)
            (dir (if buffer-file-name
                     (file-name-directory buffer-file-name)
                   default-directory)))
        (dired dir)
        (when file
          (dired-goto-file file)))))
  :custom
  (dired-dwim-target t)
  (dired-listing-switches "-alh")
  :config
  (bind-key "C-c C-e" #'wdired-change-to-wdired-mode dired-mode-map)
  (with-eval-after-load 'evil
    (evil-define-key 'normal dired-mode-map
      (kbd "a") #'wdired-change-to-wdired-mode
      (kbd "c") #'wdired-change-to-wdired-mode
      (kbd "i") #'wdired-change-to-wdired-mode)))

(use-package wdired
  :straight nil
  :ensure nil
  :after dired
  :custom
  (wdired-allow-to-change-permissions t)
  (wdired-create-parent-directories t))

(use-package dired-subtree
  :after dired
  :functions dired-subtree-toggle dired-subtree-cycle
  :defines dired-mode-map
  :config
  (bind-key "<tab>" #'dired-subtree-toggle dired-mode-map)
  (bind-key "<backtab>" #'dired-subtree-cycle dired-mode-map))

(use-package org
  :commands (org-capture org-agenda org-tempo)
  :defines
  org-duration-format
  org-capture-templates
  :init
  (setq org-agenda-files
	'("~/Documents/org/"))
  (setq org-duration-format (quote h:mm))
  (setq org-hide-emphasis-markers t)
  (setq org-startup-folded 'content)
  (setq org-todo-keywords
        '(( sequence "TODO(t)" "NEXT(n)" "PEND(p)" "|" "DONE(d)" "CANC(c)")))
  (setq org-capture-templates
        '(("w" "Work")
          ("wt" "Task" entry (file+headline "~/Documents/org/work.org" "Tasklist")
           "* TODO  %?\nDEADLINE: %t" :prepend t)
          ("p" "Personal")
          ("pt" "General Task" entry (file+headline "~/Documents/org/personal.org" "Tasklist")
           "* TODO  %?\nDEADLINE: %t" :prepend t)
          ("j" "Journal")
          ("jj" "Journal" entry (file+olp+datetree "~/Documents/org/journal/journal.org")
           "* Entry for %U\n%?"))))
(use-package org-bullets
  :hook (org-mode . org-bullets-mode)
  :custom (org-bullets-bullet-list '("●" "○")))
(use-package evil-org
  :after (org evil)
  :functions evil-org-agenda-set-keys
  :defines evil-org-mode
  :hook (org-mode . (lambda () evil-org-mode))
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(use-package hl-todo
  :ensure t
  :functions global-hl-todo-mode
  :defines hl-todo-highlight-punctuation
  :config
  (setq hl-todo-highlight-punctuation ":")
  (global-hl-todo-mode +1))

(defun jdo/start-up ()
  "Start up hook functionality."
  (message "Emacs ready in %s with %d GCs"
           (emacs-init-time)
           gcs-done))
(add-hook 'emacs-startup-hook #'jdo/start-up)

(provide 'init)
;;; init.el ends here
