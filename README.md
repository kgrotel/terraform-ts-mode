# terraform-ts-mode.el

Major mode of [Terraform](http://www.terraform.io/) configuration file. This mode uses Tresitter for Syntac highlighting and eglot as LSP


## Installation

currently only manual installation is supported. eglot requires a running terraform-ls. The mode will attach to it automatically and configure eglot accordingly.

Treesitter Grammar needs to be installed like that:

```
  (setq treesit-language-source-alist
   '((terraform . ("https://github.com/MichaHoffmann/tree-sitter-hcl"  "`main"  "dialects/terraform/src"))))
```

Don´t forget to to run ```(treesit-install-language-grammar)```

## Features

- Syntax highlighting
- Indentation
- imenu
- Formatting using `terraform fmt`

## Contribute

This mode is currently far from perfect i use it for my daily work, but lot of stuff could be done better. 


