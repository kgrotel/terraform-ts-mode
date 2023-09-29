;;; my-cabal-mode.el --- My Cabal mode -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; TODO
;; - format, run terraform-fmt on buffer


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

(defcustom terraform-ts-mode-hook nil
  "Hook called by `terraform-ts-mode'."
  :type 'hook
  :group 'terraform)

;; CUSTOM VAR
(defcustom terraform-ts-indent-level 2
  "The tab width to use when indenting."
  :type 'integer
  :group 'terraform)

(defcustom terraform-ts-format-on-save t
  "Format buffer on save"
  :type 'boolean
  :group 'terraform)

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

;; MODE VARS
(defvar terraform-ts--builtin-attributes
  '("for_each" "count" "source" "type" "default" "providers")
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
     ((expression (variable_expr (identifier) @font-lock-keyword-face) (get_attr (identifier) @font-lock-property-name-face))
       (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--builtin-expressions) eol)) @font-lock-keyword-face)) ; local, each and count
     ((expression (variable_expr (identifier) @font-lock-keyword-face) :anchor (get_attr (identifier) @font-lock-function-call-face) (get_attr (identifier) @font-lock-property-name-face) :* )
       (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--named-expressions) eol)) @font-lock-keyword-face)) ; module and var
     ((expression (variable_expr (identifier) @font-lock-type-face) :anchor (get_attr (identifier) @font-lock-function-call-face) (get_attr (identifier) @font-lock-property-name-face) :* ))
    )
   
   :language 'terraform
   :feature 'interpolation
   '((interpolation "#{" @font-lock-misc-punctuation-face)
     (interpolation "}" @font-lock-misc-punctuation-face))

   
   :language 'terraform
   :feature 'blocks
   `(
     ((attribute (identifier) @font-lock-builtin-face) (:match ,(rx-to-string `(seq bol (or ,@terraform-ts--builtin-attributes) eol)) @font-lock-builtin-face))
     ((attribute (identifier) @font-lock-property-name-face))
     )
   
   :language 'terraform
   :feature 'blocks
   '(
     ((block (identifier) @font-lock-keyword-face (string_lit (template_literal) @font-lock-type-face) (string_lit (template_literal) @font-lock-function-name-face)))
    )
   
   :language 'terraform
   :feature 'blocks
   '(
     ((block (identifier) @font-lock-keyword-face (string_lit (template_literal) @font-lock-function-name-face) :?))
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
     ((node-is "touple_end") parent-bol 0)
     ((parent-is "function_call") parent-bol ,terraform-ts-indent-level)
     ((parent-is "object") parent-bol ,terraform-ts-indent-level)
     ((parent-is "touple") parent-bol ,terraform-ts-indent-level)
     ((parent-is "block") parent-bol ,terraform-ts-indent-level))))

(defun terraform-format-buffer ()
  "Rewrite current buffer in a canonical format using terraform fmt."
  (interactive)
  (let ((buf (get-buffer-create "*terraform-fmt*")))
    (if (zerop (call-process-region (point-min) (point-max)
                                    "terraform" nil buf nil "fmt" "-no-color" "-"))
        (let ((point (point))
              (window-start (window-start)))
          (erase-buffer)
          (insert-buffer-substring buf)
          (goto-char point)
          (set-window-start nil window-start))
      (message "terraform fmt: %s" (with-current-buffer buf (buffer-string))))
    (kill-buffer buf)))

(define-minor-mode terraform-format-on-save-mode
  "Run terraform-format-buffer before saving current buffer."
  :lighter ""
  (if terraform-ts-format-on-save
      (add-hook 'before-save-hook #'terraform-format-buffer nil t)
    (remove-hook 'before-save-hook #'terraform-format-buffer t)))

;; MODE
(define-derived-mode terraform-ts-mode prog-mode "Terraform"
  "Terraform Tresitter Mode"
  :group 'terraform
  :syntax-table terraform-ts--syntax-table

  (when terraform-ts-format-on-save
    (terraform-format-on-save-mode 1))
  
  (unless (treesit-ready-p 'terraform)
    (error "Tree-sitter for Terraform isn't available"))

  (treesit-parser-create 'terraform)

  ;; Eglot integration
  (add-hook 'terraform-ts-mode-hook 'eglot-ensure)
  (with-eval-after-load 'eglot
    (put 'terraform-ts-mode 'eglot-language-id "terraform")
    (add-to-list 'eglot-server-programs
       '(terraform-ts-mode . ("terraform-ls" "serve"))))
  ;; replaced -> (terraform-ts-mode :languageId terraform) 
  ;; Comments.
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

  ;; Imenu.
  (setq-local treesit-simple-imenu-settings '((nil "\\`pair\\'" nil nil)))
  
  (treesit-major-mode-setup))
  
;;;###autoload
(if (treesit-ready-p 'terraform) (add-to-list 'auto-mode-alist '("\\.tf\\(vars\\)?\\'" . terraform-ts-mode)))
 
(provide 'terraform-ts-mode)

;;; terraform-ts-mode.el ends here
