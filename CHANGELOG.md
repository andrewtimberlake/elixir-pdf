# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.7.0 (2024-07-12)

- Add `autoprint/1` to automatically open the print dialog in a browser

## 0.6.1 (2023-01-19)

- Fix bug with zero width strings and empty rows (also fixes [#24])
- Fix issue with nil cap height [#35]
- Raise RuntimeError when attempting to add text without a font [#36]
- Fix typespec for `text_wrap/5` [#37]

## 0.6.0 (2021-12-07)

- Add `:odd` and `:even` to `:row_style` on table with a lower precedence than indexed styles
- Fix bug where only the first non-WinAnsi character was replaced [#32]

## 0.5.0 (2020-12-02)

- Catch errors raised within the GenServer and re-raise them in the calling process

## 0.4.0 (2020-08-12)

- Add `:encoding_replacement_character` option to supply a replacement character when encoding fails
- Add `:allow_row_overflow` option to `Pdf.table/4` to allow row contents to be split across pages

## 0.3.7 (2020-04-29)

- Bug fix: Fix memory leak by stopping internal processes

## 0.3.6 (2020-04-22)

- Bug fix: Correctly handle encoded text as binary, not UTF-8 encoded string
- Bug fix: External fonts now work like built-in fonts #17
- Bug fix: Reset colours changed by attributed text
- Bug fix: Fix global options for text_at/4 when using a string #11

## 0.3.5 (2020-04-14)

- Deprecate: `Pdf.delete/1` in favour of `Pdf.cleanup/1`
- Deprecate: `Pdf.open/2` in favour of `Pdf.build/2`
