---
title: 'Vocabulary Registry model subsystem'
output:
  html:
    to: html
    standalone: true
    css: ../css/pandoc.css
    lua-filter: ../pandoc/links-md-to-html.lua
    toc: true
comment: |
  You can use panrun on this file, to make HTML:
  panrun Vocabulary_Registry_model_subsystem.md > Vocabulary_Registry_model_subsystem.html
  To generate HTML using pandoc, you'll need these settings:
  pandoc -s --toc --css ../css/pandoc.css -f markdown -t html --lua-filter=../pandoc/links-md-to-html.lua Vocabulary_Registry_model_subsystem.md > Vocabulary_Registry_model_subsystem.html
  To generate PDF:
  pandoc -s --toc -f markdown -o Vocabulary_Registry_model_subsystem.pdf Vocabulary_Registry_model_subsystem.md
  Or, starting from previously-generated HTML:
  wkhtmltopdf --zoom 2 --user-style-sheet ../conf/pandoc-wkhtmltopdf.css Vocabulary_Registry_model_subsystem.html Vocabulary_Registry_model_subsystem.pdf

...

This page describes both the primary model subsystem that supports the
publication workflow, and the fixed-time model subsystem that supports
the notification subsystem.

# Introduction

Inside the Registry web application, vocabulary metadata is represented
in a number of ways:

- The "legacy" Toolkit database entity classes, e.g.,
  `au.org.ands.vocabs.toolkit.db.model.Vocabulary`.
  - In the Registry web application, these classes are used only
    during the database migration process.
- The new Registry database entity classes, e.g.,
  `au.org.ands.vocabs.registry.db.entity.Vocabulary`.
  - The source code of these classes is generated from the database
    definition; see
    [Vocabulary Registry database schema and code generation](Vocabulary_Registry_database_schema_and_code_generation.md).
  - Each instance of these classes represents one row of a table of
    the registry database.
  - Please refer to the diagrams attached to the page
    [Vocabulary Registry design diagrams](Vocabulary_Registry_design_diagrams.md).
    In particular, the diagrams
    [vocabs-just-classes.pdf](../diagrams/design/vocabs-just-classes.pdf)
    and
    [vocabs-with-attributes.pdf](../diagrams/design/vocabs-with-attributes.pdf)
    show the relationships between the registry database entity
    classes.
  - Access to the database is done using the corresponding (generated)
    DAO classes, e.g.,
    `au.org.ands.vocabs.registry.db.dao.VocabularyDAO`.
- The new Registry schema classes, e.g.,
  `au.org.ands.vocabs.registry.schema.vocabulary201701.Vocabulary`.
  - The source code of these classes is generated from the registry
    XML schema definition; see
    [Vocabulary Registry XML Schemas](Vocabulary_Registry_XML_Schemas).
  - Each instance of these classes represents an element of XML/JSON
    data passed into or out of the API.

# Motivation for the model subsystem: API requests, publication workflow

An incoming request of the registry might:

- include request data in registry schema format
- need to get data from the database
- need to update (insert, update, delete) data in the database
- need to provide a response in registry schema format

The most simple "getter" type requests are currently handled directly
in API methods. For example,
`au.org.ands.vocabs.registry.api.user.GetVocabularies.getVocabularyById()`
directly invokes DAO methods to get the database data, and then uses
mapper methods (see
[Vocabulary Registry mappers between database and schema objects](Vocabulary_Registry_mappers_between_database_and_schema_objects.md))
to produce the required response in registry schema format.

For anything more complicated, including any operation that could be
considered under the heading "publication", a "model subsystem" has
been implemented: it is described in the following sections.

# Design

Please refer to the diagrams attached to the page
[Vocabulary Registry design diagrams](Vocabulary_Registry_design_diagrams.md). In
particular, the diagram
[vocabulary-model.pdf](../diagrams/design/vocabulary-model.pdf) is a
class diagram of the model classes.

The state of a vocabulary is represented in the database as multiple
rows of multiple tables. In order to manage this complexity, we take a
"divide and rule" approach. The basic idea is that, corresponding to
each database entity class involved in the representation of a
vocabulary, there is a model class that encapsulates the state of the
vocabulary in the database and provides methods that implement the
high-level operations needed by the API. For example, corresponding to
the database entity `Vocabulary` class, there is a `VocabularyModel`
class.

Note: related entities (and their associated related entity identifiers)
are considered "first class" and have their own lifecycles, independent
of vocabularies. So, the model subsystem includes a representation of
the *associations* between vocabularies and related entities, but not
the related entities *themselves*.

# Interface

Access to the model subsystem is (mostly, for now) mediated through
the `ModelMethods` class. Its methods are as follows:

- `createVocabularyModel`: create an instance of the model for a
  vocabulary. This fetches the data for the vocabulary from the
  database, including both current and draft instances, and for all
  related metadata (versions, access points).
  - The return value of this method is an instance of
    `VocabularyModel`. Some of the methods of this class are public:
    - `hasCurrent`: does the vocabulary have a current instance?
    - `hasDraft`: does the vocabulary have a draft instance?
- `getCurrent`: if the vocabulary has a current instance, this method
  returns a representation of the current instance, in registry schema
  format. The method has flag parameters to select inclusion/exclusion
  of nested version, access point, and related entity/vocabulary
  elements.
- `getDraft`: if the vocabulary has a draft instance, this method
  returns a representation of the draft, in registry schema format.
  The method has flag parameters to select inclusion/exclusion of
  nested version, access point, and related entity/vocabulary
  elements.
- `deleteOnlyCurrentVocabulary`: delete only the current instance of
  the vocabulary.
- `deleteOnlyDraftVocabulary`: delete only the draft instance of the
  vocabulary.
- `makeCurrentVocabularyDraft`: for a vocabulary that exists only as a
  current instance (i.e., no draft), make the current instance into a
  draft. This serves as a type of "unpublish" operation.
- `applyChanges`: this is the main "workhorse" of the model subsystem.
  One of the parameters is data in registry schema format, that is to
  be "applied" to the model. The data can specify either current
  ("published" or "deprecated") data, or draft data. The database is
  updated accordingly, and the publication workflow is applied, if
  appropriate.

# Using the model subsystem

Clients of the `ModelMethods` class must provide a JPA `EntityManager`
instance for the Registry database. The client is responsible for the
lifecycle of the `EntityManager` instance, i.e., creating it and
closing it.

If the client will be making requests that require database changes,
the client must have begun a transaction before invoking
`createVocabularyModel`, and is responsible for committing the
transaction at the end, or rolling it back if the model subsystem
generates an exception.

There are numerous examples of read-only and read-write uses of the
model subsystem in the test suite. See, e.g., the methods of
`au.org.ands.vocabs.toolkit.test.arquillian.RegistryModelTests`, such
as `testGetDraftVoVRE1` (read-only) and
`testApplyChangesCurrentVoVRE1` (read-write).

**Very important note:** the model subsystem supports more behaviour
than is allowed by the current business rules. For example, the model
subsystem supports working with versions that have no access points.
This is to allow for future expansion. The business rule that
specifies that every version must specify (either explicitly, or by
the setting of the version-level flags for import, publish, etc.) at
least one access point, is implemented in the validation subsystem
used by the API methods (i.e., the `CheckVocabularyImpl` class). So
what? See the "Automated tests" section below for further explanation.

# Implementation

The code is in the package `au.org.ands.vocabs.registry.model` and its
subpackages.

Some of the classes contain code that is of interest from a computer
science point of view: the `VersionsModel`, `AccessPoinstModel`,
`VocabularyRelatedEntitiesModel`, and
`VocabularyRelatedVocabulariesModel` classes use an implementation of
an efficient sequence comparison algorithm (provided by the Apache
Commons Collections library; see
<https://commons.apache.org/proper/commons-collections/javadocs/api-4.1/org/apache/commons/collections4/sequence/package-summary.html>)
to determine a minimal set of database insertions/updates/deletions to
be performed. See the child page
[Vocabulary Registry model subsystem sequences](Vocabulary_Registry_model_subsystem_sequences)
for more details.

# Automated tests

There are automated tests!

Please note once again the **Very important note:** the model
subsystem supports more behaviour than is allowed by the current
business rules.  For example, the model subsystem supports working
with versions that have no access points. This is to allow for future
expansion. The business rule that specifies that every version must
specify (either explicitly, or by the setting of the version-level
flags for import, publish, etc.) at least one access point, is
implemented in the validation subsystem used by the API methods (i.e.,
the `CheckVocabularyImpl` class). So, there *are* automated tests that
work with versions that have no access points. And there ought to be
(but currently aren't) tests that check that the business rules are
applied to vocabulary metadata that comes in through the API methods.

Please see
`src/test/java/au/org/ands/vocabs/toolkit/test/arquillian/RegistryModelTests.java`
for the registry model test driver methods.

There are some basic conventions that apply to the naming of the
workflow test methods.

First, method names *may* include one or more codes that indicate
which part(s) of the model are exercised by the test. Those codes are
as follows. (This list also appears in the class-level Javadoc comment
of the `RegistryModelTests` class.)

+-------+------------------------------------------------------------------------------------+
| Code  | Meaning                                                                            |
+:======+:===================================================================================+
| `Vo`  | `VocabularyModel`                                                                  |
+-------+------------------------------------------------------------------------------------+
| `Ve`  | `VersionModel`                                                                     |
+-------+------------------------------------------------------------------------------------+
| `VRE` | `VocabularyRelatedEntitiesModel`                                                   |
+-------+------------------------------------------------------------------------------------+
| `VRV` | `VocabularyRelatedVocabulariesModel`                                               |
+-------+------------------------------------------------------------------------------------+
| `AP`  | `AccessPointModel`                                                                 |
+-------+------------------------------------------------------------------------------------+
| `VA`  | `VersionArtefactModel`                                                             |
+-------+------------------------------------------------------------------------------------+
| `W`   | Workflow processing subsystem (i.e., there is at least one task which will be run) |
+-------+------------------------------------------------------------------------------------+

Second, method names *may* include one of the names of the methods in
the `ModelMethods` class.

Third, methods are numbered sequentially; each combination of model
classes and `ModelMethods` method has its own numbering.

So, for example, `testDeleteOnlyDraftVoVREVRV1` is the first test of the
combination of the `deleteOnlyDraftVocabulary` method that exercises the
`VocabularyModel`, `VocabularyRelatedEntitiesModel`,
and `VocabularyRelatedVocabulariesModel` model classes: it happens to
test deleting the draft instance for which there is only a draft.
Similarly, `testDeleteDraftLeavingCurrentVoVRE1` is the first test of
the combination of the `deleteOnlyDraftVocabulary` method that exercises
the `VocabularyModel` and `VocabularyReatedEntitiesModel` model classes,
that happens to test deleting the draft instance for which there is also
a current instance (i.e., which should remain untouched).

Here is a snapshot (taken 2018-02-05) of the list of test methods for
the model subsystem:

``` text
testApplyChangesCurrentVoVRE1
testApplyChangesCurrentVoVRE2
testApplyChangesCurrentVoVREVRV1
testApplyChangesCurrentVoVREVRV2
testApplyChangesCurrentVoVREVe1
testApplyChangesCurrentVoVREVe2
testApplyChangesDraftVoVRE1
testApplyChangesDraftVoVRE2
testApplyChangesDraftVoVREVRV1
testApplyChangesDraftVoVREVRV2
testApplyChangesDraftVoVREVe1
testApplyChangesDraftVoVREVe2
testDeleteCurrentLeavingDraftVoVRE1
testDeleteCurrentLeavingDraftVoVREVRV1
testDeleteCurrentLeavingDraftVoVREVe1
testDeleteDraftLeavingCurrentVoVRE1
testDeleteDraftLeavingCurrentVoVREVRV1
testDeleteDraftLeavingCurrentVoVREVe1
testDeleteOnlyCurrentVoVRE1
testDeleteOnlyCurrentVoVREVRV1
testDeleteOnlyCurrentVoVREVe1
testDeleteOnlyDraftVoVRE1
testDeleteOnlyDraftVoVREVRV1
testDeleteOnlyDraftVoVREVe1
testGetDraftVoVRE1
testGetDraftVoVRE2
testGetDraftVoVREVRV1
testGetDraftVoVREVRV2
testGetDraftVoVREVe1
testGetDraftVoVREVe2
testMakeCurrentVocabularyDraftVoVRE1
testMakeCurrentVocabularyDraftVoVREVRV1
testMakeCurrentVocabularyDraftVoVREVe1
```

# Fixed-time model subsystem

The model subsystem described above models current and draft instances
only.

There is also a "fixed-time model subystem" that models instances as
they may (or may not) have existed at *any* timestamp. The code is in
the package `au.org.ands.vocabs.registry.model.fixedtime`. (It also
makes use of some of the classes in the `sequence` subpackage of the
main model package.)

This subsystem is currently used to support the notification subsystem,
as follows. Each vocabulary that may have changed during a given
notification period is fetched into two instances of the fixed-time
model subsystem: the timestamps used are the beginning and end of the
notification period. There is a method of this subsystem that implements
comparison of these two instances.

Because this subsystem has been implemented in the first instance to
support the notification subsystem, its capabilities are limited. In
particular, it does not model all the components of the vocabulary
metadata. To be specific: only Vocabulary, Version, and Access Point
entities are currently modelled. Therefore, a "time machine" capability
that would (for example) enable a portal user to view the vocabulary
metadata as it was at a particular point in the past is not currently
supported ... but it could be in future.
