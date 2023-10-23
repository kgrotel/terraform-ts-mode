;;; terraform-ts-mode.el --- Terraform major mode using Treesitter and eglot  -*- lexical-binding: t -*-

;;; Copyright (C) 2022-2027 Kai Grotelüschen

;; Author:     Kai Grotelueschen <kgr@gnotes.de>
;; Maintainer: Kai Grotelueschen <kgr@gnotes.de>
;; Version:    0.4
;; Keywords:   elisp, extensions
;; Homepage:   https://github.com/kgrotel/terraform-ts-mode
;; Package-Requires: ((emacs "29.1"))

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see http://www.gnu.org/licenses.


;;; Commentary:

;; This is a terraform mode using treesit. There are still quite some
;; Isues with using Treesitter for imenu and Highlight so any kind of
;; help is greatly appreaciated

;;; Code:

(require 'treesit)
(require 'eglot)
(eval-when-compile (require 'rx))

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-query-capture "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defgroup terraform nil
  "Support terraform code."
  :link '(url-link "https://www.terraform.io/")
  :group 'languages)

;; module customizions

(defcustom terraform-ts-mode-hook nil
  "Hook called by `terraform-ts-mode'."
  :type 'hook
  :group 'terraform)

(defcustom terraform-ts-indent-level 2
  "The tab width to use when indenting."
  :type 'integer
  :group 'terraform)

(defcustom terraform-ts-format-on-save t
  "Format buffer on save using eglot-format"
  :type 'boolean
  :group 'terraform)

(defcustom terraform-ts-eglot-debug nil
  "diasable debugging of eglot (mostly eglot logging) to improve performance"
  :type 'boolean
  :group 'terraform)

;; module facses

(defface terraform-resource-type-face
  '((t :inherit font-lock-type-face))
  "Face for resource names."
  :group 'terraform-mode)

(defface terraform-resource-name-face
  '((t :inherit font-lock-function-name-face))
  "Face for resource names."
  :group 'terraform-mode)

(defface terraform-builtin-face
  '((t :inherit font-lock-builtin-face))
  "Face for builtins."
  :group 'terraform-mode)

(defface terraform-variable-name-face
  '((t :inherit font-lock-variable-name-face))
  "Face for varriables."
  :group 'terraform-mode)

;; mode vars 

(defvar terraform-ts--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?- "_" table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?# "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23" table)    
    table)
  "Syntax table for `terraform-ts-mode'.")

;; Imenu

;; MODE VARS
(defvar terraform-ts--builtin-attributes
  '("for_each" "count" "source" "type" "default" "providers" "provider")
  "Terraform builtin attributes for tree-sitter font-locking.")

(defvar terraform-ts--builtin-expressions 
  '("local" "each" "count")
  "Terraform builtin expressions for tree-sitter font-locking.")

(defvar terraform-ts--named-expressions 
  '("var" "module")
  "Terraform named expressions for tree-sitter font-locking.")

(defvar terraform-ts--treesit-font-lock-rules
  (treesit-font-lock-rules
   :language 'terraform
   :feature 'comments
   '((comment) @font-lock-comment-face) ;; checkOK
   
   :language 'terraform
   :feature 'brackets
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face) ;; checkOK 
   
   :language 'terraform
   :feature 'delimiters
   '(["." ".*" "," "[*]" "=>"] @font-lock-delimiter-face) ;; checkOK

   :language 'terraform
   :feature 'operators
   '(["!"] @font-lock-negation-char-face)
   
   :language 'terraform
   :feature 'operators
   '(["\*" "/" "%" "\+" "-" ">" ">=" "<" "<=" "==" "!=" "&&" "||"] @font-lock-operator-face)
 
   :language 'terraform
   :feature 'builtin
   '((function_call (identifier) @font-lock-builtin-face)) ;; checkOK

   :language 'terraform
   :feature 'objects
   '((object_elem key: (expression (variable_expr (identifier) @font-lock-property-name-face))))
   
   :language 'terraform
   :feature 'expressions 
   `(
     ((expression (variable_expr (identifier) @terraform-builtin-face)
		  (get_attr (identifier) @font-lock-property-name-face))
      (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--builtin-expressions) eol)) @terraform-builtin-face)) ; local, each and count
     
     ((expression (variable_expr (identifier) @terraform-builtin-face)
		  :anchor (get_attr (identifier) @font-lock-function-call-face)
		  (get_attr (identifier) @font-lock-property-name-face) :* )
      (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--named-expressions) eol)) @terraform-builtin-face)) ; module and var
     
     ((expression (variable_expr (identifier) @terraform-builtin-face)
		  :anchor (get_attr (identifier) @terraform-resource-type-face)
		  (get_attr (identifier) @terraform-resource-name-face) 
		  (get_attr (identifier) @font-lock-property-name-face) :* )
      (:match "data"  @terraform-builtin-face))
     
     ((expression (variable_expr (identifier) @terraform-resource-type-face)
		  :anchor (get_attr (identifier) @terraform-resource-name-face)
		  (get_attr (identifier) @font-lock-property-name-face) :* ))  ; that should be a resource 
    )
   
   :language 'terraform
   :feature 'interpolation
   '((interpolation "#{" @font-lock-misc-punctuation-face)
     (interpolation "}" @font-lock-misc-punctuation-face))

   
   :language 'terraform
   :feature 'blocks
   `(
     ((attribute (identifier) @terraform-builtin-face) (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--builtin-attributes) eol)) @terraform-builtin-face))
     ((attribute (identifier) @terraform-variable-name-face))
     )
   
   :language 'terraform
   :feature 'blocks
   '(
     ((block (identifier) @terraform-builtin-face (string_lit (template_literal) @font-lock-type-face) (string_lit (template_literal) @font-lock-function-name-face)))
    )
   
   :language 'terraform
   :feature 'blocks
   '(
     ((block (identifier) @terraform-builtin-face (string_lit (template_literal) @font-lock-function-name-face) :?))
    )

   :language 'terraform
   :feature 'conditionals
   '(["if" "else" "endif"] @font-lock-keyword-face)
    
   :language 'terraform
   :feature 'constants
   '((bool_lit) @font-lock-constant-face) ;; checkOK
   
   :language 'terraform
   :feature 'numbers
   '((numeric_lit) @font-lock-number-face) ;; checkOK

   :language 'terraform
   :feature 'strings
   '((string_lit (template_literal))  @font-lock-string-face)  
  )
  "Tree-sitter font-lock settings.")

(defvar terraform-ts--indent-rules
  `((terraform
     ((node-is "block_end") parent-bol 0)
     ((node-is "object_end") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "tuple_end") parent-bol 0)
     ((parent-is "function_call") parent-bol ,terraform-ts-indent-level)
     ((parent-is "object") parent-bol ,terraform-ts-indent-level)
     ((parent-is "tuple") parent-bol ,terraform-ts-indent-level)
     ((parent-is "block") parent-bol ,terraform-ts-indent-level))))

;; Major Mode def 
(define-derived-mode terraform-ts-mode prog-mode "Terraform"
  "Terraform Tresitter Mode"
  :group 'terraform
  :syntax-table terraform-ts--syntax-table

  ;; treesit - add terraform grammar
  (add-to-list 'treesit-language-source-alist
      '(terraform . ("https://github.com/MichaHoffmann/tree-sitter-hcl"  "main"  "dialects/terraform/src")))

  ;; treesit - check grammar is readdy if not most likly in need to be installed
  (unless (treesit-ready-p 'terraform)
    (treesit-install-language-grammar 'terraform))

  ;; treesit - init parser
  (treesit-parser-create 'terraform)
  
  ;; eglot - integrate mode into terraform-ts-mode
  (add-hook 'terraform-ts-mode-hook 'eglot-ensure)
  (with-eval-after-load 'eglot
    (put 'terraform-ts-mode 'eglot-language-id "terraform")
    (add-to-list 'eglot-server-programs
		 '(terraform-ts-mode . ("terraform-ls" "serve"))))

  ;; eglot - use format on save
  (if terraform-ts-format-on-save
    (add-hook 'before-save-hook 'eglot-format)
    (remove-hook 'before-save-hook 'eglot-format))

  ;; eglot - disable debugging eglot - increase performance
  (unless terraform-ts-eglot-debug
    (fset #'jsonrpc--log-event #'ignore) ; disable eglot event logging
    (setq eglot-events-buffer-size 0)    ; decrease event logging buffer (not needed see above)
    (setq eglot-sync-connect nil)        ; disabling  waiting for eglot sync done / might mean that eglot is not avail at opening file
  )

  (setq-local comment-start "#")
  (setq-local comment-use-syntax t)
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *")
  
  ;; Electric
  (setq-local electric-indent-chars (append "{}[]()" electric-indent-chars))

  ;; Indent.
  (setq-local treesit-simple-indent-rules terraform-ts--indent-rules)

  ;; Navigation.
  ;; (setq-local treesit-defun-type-regexp (rx (or "pair" "object")))
  ;; (setq-local treesit-defun-name-function #'json-ts-mode--defun-name)
  ;; (setq-local treesit-sentence-type-regexp "pair")

  ;; Font-lock
  (setq-local treesit-font-lock-feature-list '((comments)
					       (keywords attributes blocks strings numbers constants objects output modules workspaces vars)
					       (builtin brackets delimiters expressions operators interpolations conditionals)
					       ()))
  (setq-local treesit-font-lock-settings terraform-ts--treesit-font-lock-rules)

  ;; Imenu ... todo
  ;; (setq-local treesit-simple-imenu-settings
  ;;	       `((nil "block" nil nil)))
   
  (treesit-major-mode-setup))
  
;;; autoload
(add-to-list 'auto-mode-alist '("\\.tf\\(vars\\)?\\'" . terraform-ts-mode))
 
(provide 'terraform-ts-mode)
;;; terraform-ts-mode.el ends here
