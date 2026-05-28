# poietikês

Prosodic analysis in Julia, inspired by Python [prosodic](https://pypi.org/project/prosodic/). 

## Install

## Quickstart

## About

The goal for poeitikes is to retain the metrical-phonological capabilities of prosodic, and extend its capabilities into other defined poetic forms, includes those that operate on morae rather than syllables. 

Poietikes has two pipelines: 
- prescriptive: given a poetic text, its Form, and its Language, explicitly breaks down the given text in accordance with a Form x Language dispatch, allowing for the same form to be analyzed based on its differences across languages (haiku are analyzed with morae in Japanese and syllables in English). 
- descriptive: given a poetic text, extract features from the text, and output an estimate of source language and poetic form. 

Both pipelines are based on analysis of the same prosodic and phonological features, as described in the Methodolgy section. Prosodic parsing is relative to the text language (a parameter in the prescriptive pipeline, or a product of language detection in the descriptive pipeline). 

Currently, this has built-in support for English, Japanese, French, Spanish, Italian, and Sanskrit, with rhyming data from CMUdict for English and Lexique for French. Users are invited to add their own Forms via TOML/JSON.

```julia
struct DataForm <: Form
    name::Symbol
    specs::FormSpecs          # carried data, not dispatched methods
end
```


