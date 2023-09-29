[![License: GPL 3](https://img.shields.io/badge/license-GPL_3-green.svg)](http://www.gnu.org/licenses/gpl-3.0.txt)

# terraform-ts-mode.el

Major mode of [Terraform](http://www.terraform.io/) configuration file. This mode uses Tresitter for syntax highlighting and eglot as LSP

## Installation

currently only manual installation is supported. eglot requires a running terraform-ls. The mode will attach to it automatically and configure eglot accordingly.

In case treesitter terraform grammar is not installed it will be installed.

## Features

- Syntax highlighting
- Indentation
- format on save (via eglot)
- Code Suggestions

## Notes & Ussues

- regarding iddentation: terraform-ls doesnt support indentation aside 2 which meansindentation should not be changed. Never the less treesit-identation is set but only correct identation while editing
- currently only treesit default imenu is used which is not fitting very well

## Contribute

This mode is currently far from perfect i use it for my daily work, but lot of stuff could be done better. 


