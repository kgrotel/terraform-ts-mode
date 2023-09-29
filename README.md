[![License: GPL 3](https://img.shields.io/badge/license-GPL_3-green.svg)](http://www.gnu.org/licenses/gpl-3.0.txt)
[![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml)


# terraform-ts-mode.el

Major mode of [Terraform](http://www.terraform.io/) configuration file. This mode uses Tresitter for syntax highlighting and eglot as LSP


## Installation

currently only manual installation is supported. eglot requires a running terraform-ls. The mode will attach to it automatically and configure eglot accordingly.

Treesitter Grammar needs to be installed like that:

```
  (setq treesit-language-source-alist
   '((terraform . ("https://github.com/MichaHoffmann/tree-sitter-hcl"  "main"  "dialects/terraform/src"))))
```

Don´t forget to to run ```(treesit-install-language-grammar)```

## Features

- Syntax highlighting
- Indentation
- format on save (via eglot)

## Notes

- regarding iddentation: terraform-ls doesnt support indentation aside 2 which meansindentation should not be changed. Never the less treesit-identation is set but only correct identation while editing

## Contribute

This mode is currently far from perfect i use it for my daily work, but lot of stuff could be done better. 


