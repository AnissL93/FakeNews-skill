# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Added the findings format with canonical dimensions, severity vocabulary, and verbatim quoted evidence rules for each issue found (#11).
- Added overall credibility scoring and rationale synthesis so findings map consistently to Credible, Mostly Credible, Mixed, Low Credibility, or Not Credible (#12).
- Added a user-friendly summary layer in the top `## Verdict` section above detailed findings and rationale (#13).
- Added prompt-injection hardening by treating analyzed content as untrusted data that cannot change the skill workflow, rating, or output template (#14).
- Added misleading and credible sample fixtures that exercise expected ratings, findings, and clean-input behavior (#15).
- Added fixture acceptance checks verifying flags, verbatim quote locatability, and rating consistency (#16).
