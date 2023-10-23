[![License: GPL 3](https://img.shields.io/badge/license-GPL_3-green.svg)](http://www.gnu.org/licenses/gpl-3.0.txt)  

# terraform-ts-mode.el

Major mode of [Terraform](http://www.terraform.io/) configuration file. This mode uses Tresitter for syntax highlighting and eglot as LSP

## Compatibilty

OS | emacs 29.1 | emacs Snapshot
--- | --- | ---
Ubuntu | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml)  | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml) 
MacOS | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml)  | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml) 
Windows | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml)  | [![Tests](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/kgrotel/terraform-ts-mode/actions/workflows/tests.yml) 

## Installation

currently only manual installation is supported. eglot requires a running terraform-ls. The mode will attach to it automatically and configure eglot accordingly.

In case treesitter terraform grammar is not installed it will be installed.

## Features

- Syntax highlighting
- Indentation
- format on save (via eglot-format)
- Code Suggestions

## Notes & Usage

- regarding indentation: terraform-ls and with it eglot-format does not support indentation aside 2 which means indentation should not be changed. Nevertheless treesit-identation is set but only correct identation while editing
- currently eglot auto creates imenu which is not fitting very well (working on this is next)

## Contribute

This mode is currently far from perfect i use it for my daily work, but lot of stuff could be done better. 


