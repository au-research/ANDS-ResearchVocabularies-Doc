---
title: 'Vocabulary Registry database design'
output:
  html:
    to: html
    standalone: true
    css: ../css/pandoc.css
    lua-filter: ../pandoc/links-md-to-html.lua
    toc: true
comment: |
  You can use panrun on this file, to make HTML:
  panrun Vocabulary_Registry_database_design.md > Vocabulary_Registry_database_design.html
  To generate HTML using pandoc, you'll need these settings:
  pandoc -s --toc --css ../css/pandoc.css -f markdown -t html --lua-filter=../pandoc/links-md-to-html.lua Vocabulary_Registry_database_design.md > Vocabulary_Registry_database_design.html
  To generate PDF:
  pandoc -s --toc -f markdown -o Vocabulary_Registry_database_design.pdf Vocabulary_Registry_database_design.md
  Or, starting from previously-generated HTML:
  wkhtmltopdf --zoom 2 --user-style-sheet ../conf/pandoc-wkhtmltopdf.css Vocabulary_Registry_database_design.html Vocabulary_Registry_database_design.pdf

...

# See also

- There are some nice UML diagrams that provide a logical view of the
  main database entities at: 
  [Vocabulary Registry design diagrams](Vocabulary_Registry_design_diagrams.md).

# Design principles

## General principles

- All columns are to have the property NOT NULL. Therefore, only
  *required* attributes can be columns; *optional* attributes are
  represented in the various "data" fields (represented as JSON).
- The `start_date` and `end_date` columns are explained in
  [Vocabulary database temporal data](Vocabulary_database_temporal_data.md).
- Within each main table, there are typically two id columns; the first,
  called `id`, is a surrogate key. The second is the "real" id. For
  example, the vocabularies table has `id` and `vocabulary_id`.
- Foreign keys are to be used, where possible. Because of the
  `start_date` and `end_date` columns, that means that "real" ids are
  typically not unique in the main tables. So we introduce separate
  "\*\_ids" tables just to store ids. (If in future, we use a database
  that supports SQL:2011's temporal features, it might be possible to
  implement foreign keys directly between the main tables.)
- Owners are to be role identifiers, not role names/abbreviations. When
  performing a migration, check that the values of the owner fields are
  indeed IDs, not anything else.
- The various `modified_by` columns are to have values that are role
  identifiers. But they can also be "system"/internal roles. For now, we
  use a special value `SYSTEM` where we don't otherwise have a role
  identifier to use. That means: for data migrated from the old
  database, and for the tables used for the subscription/notification
  subsystem.
- The ordering of the columns in each table follows a similar
  pattern. For a table with all possible options, that would be:
  `id` (surrogate key), `start_date`, `end_date`, "real" id, "real" ids
  for keys to other tables, `modified_by`, `status` (table-specific
  enumerated type), `type` (table-specific enumerated type), any other
  columns, `data` (JSON).
- Where a column stores values of an enumerated type, the values of the
  type are in all uppercase, with words separated by underscores.
    - This is a change from the original database, and a change to most
      instances of usual practice. (However, it is not the first time
      we have done this; e.g., types of roles, and many role names.)
    - This change is driven by the default behaviour of JPA when it
      serializes instances of enumerated types.
    - It has the advantage that instances of enumerated types will now
      stand out very clearly when working directly with the database,
      e.g., when reading database dumps.

## Design principles for JSON-flavoured columns

- In JSON-flavoured `data` fields, for a sub-field that can have an
  array value, don't store an empty array if there are no values to be
  recorded. For example, for a vocabulary, if there are no top concepts,
  don't include `"top_concepts":[]`. This is a debatable point ... but
  let's go with this for now and see if there are any
  consequences. (This is the behaviour of Jackson's serialization of
  Lists that are fields of instances of xjc-generated classes, when the
  Jackson ObjectMapper is configured with the JaxbAnnotationModule, and
  serialization inclusion is set to Include.NON\_NULL.)
- Where the path to a file in the file system is being stored in a
  JSON-flavoured `data` column, it will be stored with key `"path"`.
- Where a URL is being stored in a JSON-flavoured `data` column, it will
  be stored with key `"url"`. Where the value is to be understood as a
  prefix, to which something must be appended, it will be stored with
  key `"url-prefix"`.
- Where the IRI of a resource is being stored in a
  JSON-flavoured `data` column, it will be stored with key `"iri"`.
- On the implementation of serialization of data into JSON, please note
  the section "A note about the order of keys in JSON data" at the page
  [Vocabulary Registry mappers between database and schema objects](Vocabulary_Registry_mappers_between_database_and_schema_objects.md).

## Design principles for access points and version artefacts

It's important to keep in mind what access points and version artefacts *are*.

- An access point is something that is visible on the view page of the
  portal. For each access point, there will be at least one link on the
  view page. (For each access point of type sesameDownload, there will
  be one link for each supported RDF format.)
    - For some types of access point, the user may directly request the
      creation of an access point by specifying when adding/updating a
      vocabulary. These have source=user.
    - For some types of access point, the system is responsible for
      creation of some instances. These have source=system.
- A version artefact is something that "belongs" to the version, but
  which may or may not be directly "visible" in the portal. (For now)
  the user doesn't explicitly "ask" for the creation of these: there are
  *only* "system"-sourced version artefacts.

The distinction between user-supplied and system-controlled/generated
stuff must be worked out in the portal and in the registry API.

In the portal CMS: user-supplied stuff is visible in the CMS and the
user can edit/delete it. System-supplied stuff may not be visible in the
CMS, but if it is, the user can not edit/delete it directly. E.g., the
existence of a system-generated apiSparql access point is controlled by
the "Import" checkbox, *not* by the presence/absence of that specific
apiSparql endpoint in the CMS.

The registry API may include system-generated stuff in
responses. Indeed, it does include it when fetching the "full"
vocabulary data so that the view page can display it.

When sending data to the registry API, don't send system-generated
stuff; or, at least, don't need to send back system-generated
stuff. Whatever happens, the registry needs to "ignore" system-generated
stuff *sent* to it.

# Tables for database maintenance

We use Liquibase to do all maintenance of the Registry database
schema. Changes to the database schema of a particular instance of the
Registry database are applied *only* using Liquibase, never by running
DDL commands "manually". There is an Ant target (defined in `build.xml`)
for applying schema changes; see
[Vocabulary Registry build script and targets](Vocabulary_Registry_build_script_and_targets.md).

There are two tables used by Liquibase to maintain the database schema
within a database deployment. In general, you almost never need to pay
attention to the contents of these tables; certainly, you should *never*
make manual changes to the content of these tables.

NB: as the test system uses JPA annotations to drive the creation of
test databases, these tables are not visible during text execution.

## Table: DATABASECHANGELOG

This table has a row for every database schema operation applied to the
database. For example, there is a row for every table creation, and for
every index creation. There are also rows for "tags" which are helpful
in case a rollback is required to return to an earlier version of the
database schema (e.g., during development).

## Table: DATABASECHANGELOGLOCK

This one-row table is used by Liquibase to implement a lock on changes
to the database schema, i.e., to ensure that there is only one instance
of Liquibase operating on the database schema at a time.

# Tables just for ids

These are tables that contain only ids. Why?

- To get values that auto-increment. (MySQL does not have sequences.)
- These values can then be used as foreign keys in other tables.

So, when creating a new vocabulary, first add a row to
vocabulary\_ids. Then use the id of the resulting row as the
vocabulary\_id to insert into a new row in the vocabularies table.

## Table: vocabulary\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 2          |
+--------+---------+-------------------------------------+-------+------------+

## Table: version\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 5          |
+--------+---------+-------------------------------------+-------+------------+

## Table: version\_artefact\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 5          |
+--------+---------+-------------------------------------+-------+------------+

## Table: access\_point\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 3          |
+--------+---------+-------------------------------------+-------+------------+

## Table: related\_entity\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 7          |
+--------+---------+-------------------------------------+-------+------------+

## Table: related\_entity\_identifier\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 7          |
+--------+---------+-------------------------------------+-------+------------+

## Table: subscriber\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 7          |
+--------+---------+-------------------------------------+-------+------------+

## Table: subscriber\_email\_address\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 7          |
+--------+---------+-------------------------------------+-------+------------+

## Table: subscription\_ids

+--------+---------+-------------------------------------+-------+------------+
| Column | Type    | Extra                               | Notes | Example(s) |
+:=======+:========+:====================================+:======+:===========+
| id     | integer | auto\_increment, primary key, index |       | 7          |
+--------+---------+-------------------------------------+-------+------------+

# The main tables

## Table: vocabularies

+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| Column         | Type         | Extra               | Notes                                                                   | Example(s)                 |
+:===============+:=============+:====================+:========================================================================+:===========================+
| id             | integer      | auto\_increment,    | Surrogate key                                                           | 17                         |
|                |              | primary key,        |                                                                         |                            |
|                |              | index               |                                                                         |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| start\_date    | datetime     |                     | Value is in the UTC timezone                                            | 2016-08-15 13:50:45.123468 |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| end\_date      | datetime     |                     | Value is in the UTC timezone                                            | 9999-12-01 00:00:00        |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| vocabulary\_id | integer      | foreign key         | The "real" vocabulary id                                                | 2                          |
|                |              | references          |                                                                         |                            |
|                |              | vocabulary\_ids(id) |                                                                         |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| modified\_by   | varchar(255) |                     | The user Role ID responsible for creating this row in the table.        | rwalker                    |
|                |              |                     | *Not* (necessarily) the role that owns the vocabulary.                  |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| status         | varchar(45)  |                     | Enumerated type: CURRENT, DEPRECATED, DRAFT                             | CURRENT                    |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| slug           | varchar(255) |                     | Would be nice to use Lucene/Solr libraries to generate this             | my-vocab                   |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| owner          | varchar(255) |                     | Role ID taken from dbs\_roles.roles(role\_id);                          | ANDS                       |
|                |              |                     | either an organisational role or an individual user                     |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
|                |              |                     |                                                                         |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+
| data           | text         |                     | JSON to store everything else:                                          | {}                         |
|                |              |                     |                                                                         |                            |
|                |              |                     | - title                                                                 |                            |
|                |              |                     | - acronym                                                               |                            |
|                |              |                     | - description                                                           |                            |
|                |              |                     | - note                                                                  |                            |
|                |              |                     | - revision cycle                                                        |                            |
|                |              |                     | - creation date (the user-entered one)                                  |                            |
|                |              |                     | - language                                                              |                            |
|                |              |                     | - primary language (used to select                                      |                            |
|                |              |                     |   prefLabels for the browse tree)                                       |                            |
|                |              |                     | - other languages (i.e., languages                                      |                            |
|                |              |                     |   other than the primary language)                                      |                            |
|                |              |                     | - subjects                                                              |                            |
|                |              |                     | - top concepts: oops, move this into versions?                          |                            |
|                |              |                     | - licencing                                                             |                            |
|                |              |                     | - PoolParty project:                                                    |                            |
|                |              |                     |   - PoolParty server: id of the                                         |                            |
|                |              |                     |     entry in the `poolparty_servers` table                              |                            |
|                |              |                     |   - Project ID                                                          |                            |
|                |              |                     | - For draft records only, and for                                       |                            |
|                |              |                     |   analytics only: created date, modified date                           |                            |
|                |              |                     |   - Draft records have special, fixed                                   |                            |
|                |              |                     |     start\_date/end\_date values, so record                             |                            |
|                |              |                     |     creation/modification timestamps can't                              |                            |
|                |              |                     |     be stored there. So instead, store                                  |                            |
|                |              |                     |     them here. This may be useful for                                   |                            |
|                |              |                     |     analytics, i.e., when did someone                                   |                            |
|                |              |                     |     create this draft record?                                           |                            |
+----------------+--------------+---------------------+-------------------------------------------------------------------------+----------------------------+


Indexes:

- id (primary key)
- ix\_vocabularies\_vocabulary\_id\_end\_date: (vocabulary\_id,
  end\_date)
- ix\_vocabularies\_slug\_end\_date: (slug, end\_date)

## Table: versions

+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| Column         | Type         | Extra               | Notes                                                        | Example(s)                 |
+:===============+:=============+:====================+:=============================================================+:===========================+
| id             | integer      | auto\_increment     | Surrogate key                                                | 18                         |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| start\_date    | datetime     |                     | Value is in the UTC timezone                                 | 2016-08-15 13:50:46.123468 |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| end\_date      | datetime     |                     | Value is in the UTC timezone                                 | 9999-12-01 00:00:00        |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| version\_id    | integer      | foreign key         | The "real" version id                                        | 5                          |
|                |              | references          |                                                              |                            |
|                |              | version\_ids(id)    |                                                              |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| vocabulary\_id | integer      | foreign key         | The vocabulary id. There must be an entry                    | 2                          |
|                |              | references          | in the vocabularies table which has                          |                            |
|                |              | vocabulary\_ids(id) | start\_date/end\_date values consistent                      |                            |
|                |              |                     | with the start\_date/end\_date values of this                |                            |
|                |              |                     | entry.                                                       |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| modified\_by   | varchar(255) |                     | The user Role ID responsible for creating                    |                            |
|                |              |                     | this row in the table.                                       |                            |
|                |              |                     | *Not* (necessarily) the role that owns the vocabulary.       |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| status         | varchar(45)  |                     | Enumerated type: CURRENT, SUPERSEDED                         | CURRENT                    |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| slug           | varchar(255) |                     |                                                              |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| release\_date  | varchar(30)  |                     | This would "normally" have gone into data,                   |                            |
|                |              |                     | but we store it here at the top level,                       |                            |
|                |              |                     | in order to support queries that do something                |                            |
|                |              |                     | like "ORDER BY release\_date\_order DESC"                    |                            |
|                |              |                     | to sort versions by release date.                            |                            |
|                |              |                     | Stored as a string to allow for partial dates                |                            |
|                |              |                     | (e.g., "2015" and "2015-10").                                |                            |
|                |              |                     | NB: a partial date such as "2015"                            |                            |
|                |              |                     | will sort as though it were "2015-01-01",                    |                            |
|                |              |                     | which is nice/good enough. Allow 30 characters               |                            |
|                |              |                     | for now; this is enough to support                           |                            |
|                |              |                     | date/time/milliseconds.                                      |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+
| data           | text         |                     | JSON to store everything else:                               | {}                         |
|                |              |                     |                                                              |                            |
|                |              |                     | - title                                                      |                            |
|                |              |                     | - note                                                       |                            |
|                |              |                     | - (release date: no, store at top-level, q.v.)               |                            |
|                |              |                     | - do\_poolparty\_harvest (flag to specify                    |                            |
|                |              |                     |   harvest from the PoolParty project; only allowed           |                            |
|                |              |                     |   to be true if the vocabulary has specified                 |                            |
|                |              |                     |   a PoolParty project!)                                      |                            |
|                |              |                     | - do\_import (flag to cause creation of                      |                            |
|                |              |                     |   Sesame repository)                                         |                            |
|                |              |                     | - do\_publish (flag to cause creation of                     |                            |
|                |              |                     |   SISSVoc endpoints)                                         |                            |
|                |              |                     | - For draft records only, and for                            |                            |
|                |              |                     |   analytics only: created date, modified date                |                            |
|                |              |                     |   - Draft records have special, fixed                        |                            |
|                |              |                     |     start\_date/end\_date values, so record                  |                            |
|                |              |                     |     creation/modification timestamps can't                   |                            |
|                |              |                     |     be stored there. So instead, store                       |                            |
|                |              |                     |     them here. This may be useful for                        |                            |
|                |              |                     |     analytics, i.e., when did someone                        |                            |
|                |              |                     |     create this draft record?                                |                            |
+----------------+--------------+---------------------+--------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- version\_id
- (version\_id, end\_date)
- end\_date

## Table: version\_artefacts

See also the child page
[Vocabulary database new design: version\_artefacts](Vocabulary_database_new_design_version_artefacts.md)
for details about the various types of version artefact.

+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| Column                | Type         | Extra                      | Notes                                                                    | Example(s)                 |
+=======================+==============+============================+==========================================================================+============================+
| id                    | integer      | auto\_increment            | Surrogate key                                                            | 18                         |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| start\_date           | datetime     |                            | Value is in the UTC timezone                                             | 2016-08-15 13:50:46.123468 |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| end\_date             | datetime     |                            | Value is in the UTC timezone                                             | 9999-12-01 00:00:00        |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| version\_artefact\_id | integer      | foreign key                |                                                                          | 4                          |
|                       |              | references                 |                                                                          |                            |
|                       |              | version\_artefact\_ids(id) |                                                                          |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| version\_id           | integer      | foreign key                | The "real" version id. There must be an entry in the versions table      | 5                          |
|                       |              | references                 | which has start\_date/end\_date values consistent with the               |                            |
|                       |              | version\_ids(id)           | start\_date/end\_date values of this entry.                              |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| modified\_by          | varchar(255) |                            | The user Role ID responsible for creating this row in the table.         | rwalker                    |
|                       |              |                            | *Not* (necessarily) the role that owns the vocabulary.                   |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
|                       |              |                            |                                                                          |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| status                | varchar(45)  |                            | Enumerated type: CURRENT, PENDING                                        | CURRENT                    |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| type                  | varchar(45)  |                            | Enumerated type: FILE, RDF\_FROM\_URL, SPARQL\_ENDPOINT,                 |                            |
|                       |              |                            | CONCEPT\_LIST, CONCEPT\_TREE, ...                                        |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+
| data                  | text         |                            | JSON to store everything else:                                           | {}                         |
|                       |              |                            |                                                                          |                            |
|                       |              |                            | - for FILE: filename                                                     |                            |
|                       |              |                            | - for RDF\_FROM\_URL: rdf\_type (values are MIME types or similar)       |                            |
|                       |              |                            | - for FILE, RDF\_FROM\_URL, etc.: do\_import (flag to indicate           |                            |
|                       |              |                            |   that this should be imported into Sesame)                              |                            |
|                       |              |                            | - for CONCEPT\_TREE: filename, flags to indicate whether                 |                            |
|                       |              |                            |   this has cycles, whether it has polyhierarchies                        |                            |
|                       |              |                            |   (used to determine whether to show explanatory notes                   |                            |
|                       |              |                            |   when displaying to the user)                                           |                            |
+-----------------------+--------------+----------------------------+--------------------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- version\_artefact\_id
- (version\_artefact\_id, end\_date)
- end\_date

## Table: access\_points

See also the child page
[Vocabulary database new design: access\_points](Vocabulary_database_new_design_access_points.md) for
details about the various types of access point.

+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| Column            | Type         | Extra                  | Notes                                                                         | Example(s)                 |
+:==================+:=============+:=======================+:==============================================================================+:===========================+
| id                | integer      | auto\_increment        | Surrogate key                                                                 | 18                         |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| start\_date       | datetime     |                        | Value is in the UTC timezone                                                  | 2016-08-15 13:50:47.123468 |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| end\_date         | datetime     |                        | Value is in the UTC timezone                                                  | 9999-12-01 00:00:00        |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| access\_point\_id | integer      | foreign key            | The "real" access point id                                                    | 5                          |
|                   |              | references             |                                                                               |                            |
|                   |              | access\_point\_ids(id) |                                                                               |                            |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| version\_id       | integer      | foreign key            | The version id. There must be an entry in the versions table which has        | 2                          |
|                   |              | references             | start\_date/end\_date values consistent with the                              |                            |
|                   |              | version\_ids(id)       | start\_date/end\_date values of this entry.                                   |                            |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| modified\_by      | varchar(255) |                        | The user Role ID responsible for creating this row                            | rwalker                    |
|                   |              |                        | in the table. *Not* (necessarily) the role that                               |                            |
|                   |              |                        | owns the vocabulary.                                                          |                            |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| type              | varchar(45)  |                        | Enumerated type: FILE, SESAME\_DOWNLOAD, ...                                  |                            |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| source            | varchar(45)  |                        | Enumerated type: SYSTEM or USER                                               | SYSTEM                     |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+
| data              | text         |                        | JSON to store everything else for the portal and toolkit;                     | {}                         |
|                   |              |                        | NB: this combines the old portal\_data and toolkit\_data                      |                            |
|                   |              |                        | into one; the various APIs will split this out as required                    |                            |
+-------------------+--------------+------------------------+-------------------------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- access\_point\_id
- (access\_point\_id, end\_date)
- end\_date

## Table: related\_entities

Related entities are given "first class" status, i.e., unlike in the
original database, they are not represented directly within the JSON
data of a vocabulary. This is so that you can edit the details of a
related entity, and those details will then apply to all vocabularies
that are related to the related entity.

Related vocabularies that are *in this database* are represented in the
separate table vocabulary\_related\_vocabularies.

+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| Column              | Type         | Extra                    | Notes                                                                   | Example(s)                 |
+:====================+:=============+:=========================+:========================================================================+:===========================+
| id                  | integer      | auto\_increment          | Surrogate key                                                           | 18                         |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| start\_date         | datetime     |                          | Value is in the UTC timezone                                            | 2016-08-15 13:50:47.123468 |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| end\_date           | datetime     |                          | Value is in the UTC timezone                                            | 9999-12-01 00:00:00        |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| related\_entity\_id | integer      | foreign key              | The "real" related entity id                                            |                            |
|                     |              | references               |                                                                         |                            |
|                     |              | related\_entity\_ids(id) |                                                                         |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| modified\_by        | varchar(255) |                          | The user Role ID responsible for creating this row in the table.        | rwalker                    |
|                     |              |                          | *Not* (necessarily) the role that owns the vocabulary.                  |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| owner               | varchar(255) |                          | Copied from the owner of the vocabulary that first                      |                            |
|                     |              |                          | creates/uses this related entity?                                       |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| type                |              |                          | Enumerated type: PARTY, SERVICE, VOCABULARY (for links                  |                            |
|                     |              |                          | to vocabularies *not* stored in this database)                          |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| title               | text         |                          | All related entities have a title, so store as its own column           |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+
| data                | text         |                          | Everything else except identifiers: email, phone,                       | {}                         |
|                     |              |                          | URL, ... For identifiers, see the related\_entity\_identifiers table.   |                            |
+---------------------+--------------+--------------------------+-------------------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

-   id
-   related\_entity\_id
-   (related\_entity\_id, end\_date)
-   end\_date

## Table: related\_entity\_identifiers

This table has been split off from related\_entities so that we can do
things like, "find all vocabularies that have an association with Handle
XYZ".

+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| Column                          | Type         | Extra                                | Notes                                               | Example(s)                 |
+:================================+:=============+:=====================================+:====================================================+:===========================+
| id                              | integer      | auto\_increment                      | Surrogate key                                       | 18                         |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| start\_date                     | datetime     |                                      | Value is in the UTC timezone                        | 2016-08-15 13:50:47.123468 |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| end\_date                       | datetime     |                                      | Value is in the UTC timezone                        | 9999-12-01 00:00:00        |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| related\_entity\_identifier\_id | integer      | foreign key references               | The "real" related entity identifier id             |                            |
|                                 |              | related\_entity\_identifier\_ids(id) |                                                     |                            |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| related\_entity\_id             | integer      | foreign key references               | There must be an entry in the related\_entities     |                            |
|                                 |              | related\_entity\_ids(id)             | table which has start\_date/end\_date values        |                            |
|                                 |              |                                      | consistent with the start\_date/end\_date           |                            |
|                                 |              |                                      | values of this entry.                               |                            |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| modified\_by                    | varchar(255) |                                      | The user Role ID responsible for creating           | rwalker                    |
|                                 |              |                                      | this row in the table. *Not* (necessarily)          |                            |
|                                 |              |                                      | the role that owns the vocabulary.                  |                            |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| identifier\_type                | varchar(45)  |                                      | Enumerated type: LOCAL (catch-all for               |                            |
|                                 |              |                                      | anything the user wants to enter as                 |                            |
|                                 |              |                                      | free text), HANDLE, ORCID, ...                      |                            |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+
| identifier\_value               | text         |                                      | The value of the identifier                         |                            |
+---------------------------------+--------------+--------------------------------------+-----------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- related\_entity\_id
- (related\_entity\_id, end\_date)
- end\_date

## Table: vocabulary\_related\_entities

+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| Column              | Type         | Extra                    | Notes                                                           | Example(s)                 |
+:====================+:=============+:=========================+:================================================================+:===========================+
| id                  | integer      | auto\_increment          | Surrogate key                                                   | 18                         |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| start\_date         | datetime     |                          | Value is in the UTC timezone                                    | 2016-08-15 13:50:47.123468 |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| end\_date           | datetime     |                          | Value is in the UTC timezone                                    | 9999-12-01 00:00:00        |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| vocabulary\_id      | integer      | foreign key references   | There must be an entry in the vocabularies table                |                            |
|                     |              | vocabulary\_ids(id)      | which has start\_date/end\_date values                          |                            |
|                     |              |                          | consistent with the start\_date/end\_date                       |                            |
|                     |              |                          | values of this entry.                                           |                            |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| related\_entity\_id | integer      | foreign key references   | There must be an entry in the related\_entities table           |                            |
|                     |              | related\_entity\_ids(id) | which has start\_date/end\_date values consistent               |                            |
|                     |              |                          | with the start\_date/end\_date values of this entry.            |                            |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| modified\_by        | varchar(255) |                          | The user Role ID responsible for creating this                  | rwalker                    |
|                     |              |                          | row in the table. *Not* (necessarily) the role                  |                            |
|                     |              |                          | that owns the vocabulary.                                       |                            |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+
| relation            | varchar(45)  |                          | Enumerated type: PUBLISHED\_BY, HAS\_AUTHOR,                    |                            |
|                     |              |                          | HAS\_CONTRIBUTOR, POINT\_OF\_CONTACT, IMPLEMENTED\_BY,          |                            |
|                     |              |                          | CONSUMER\_OF, HAS\_ASSOCIATION\_WITH, IS\_PRESENTED\_BY,        |                            |
|                     |              |                          | IS\_USED\_BY, IS\_DERIVED\_FROM, ENRICHES, IS\_PART\_OF.        |                            |
+---------------------+--------------+--------------------------+-----------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- vocabulary\_id
- (vocabulary\_id, end\_date)
- end\_date

## Table: vocabulary\_related\_vocabularies

This table is for representing related vocabularies, where the related
vocabularies are also stored in the database. For related vocabularies
that are external, use related\_entities with type="VOCABULARY".

+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| Column                  | Type         | Extra                  | Notes                                                     | Example(s)                 |
+:========================+:=============+:=======================+:==========================================================+:===========================+
| id                      | integer      | auto\_increment        | Surrogate key                                             | 18                         |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| start\_date             | datetime     |                        | Value is in the UTC timezone                              | 2016-08-15 13:50:47.123468 |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| end\_date               | datetime     |                        | Value is in the UTC timezone                              | 9999-12-01 00:00:00        |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| vocabulary\_id          | integer      | foreign key references | There must be an entry in the vocabularies table          |                            |
|                         |              | vocabulary\_ids(id)    | which has start\_date/end\_date values consistent         |                            |
|                         |              |                        | with the start\_date/end\_date values of this entry.      |                            |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| related\_vocabulary\_id | integer      | foreign key references | There must be an entry in the vocabularies table          |                            |
|                         |              | vocabulary\_ids(id)    | which has start\_date/end\_date values consistent         |                            |
|                         |              |                        | with the start\_date/end\_date values of this entry.      |                            |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| modified\_by            | varchar(255) |                        | The user Role ID responsible for creating this            | rwalker                    |
|                         |              |                        | row in the table. *Not* (necessarily) the role that       |                            |
|                         |              |                        | owns the vocabulary.                                      |                            |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+
| relation                | varchar(45)  |                        | Enumerated type: HAS\_ASSOCIATION\_WITH,                  |                            |
|                         |              |                        | IS\_DERIVED\_FROM, ENRICHES, IS\_PART\_OF                 |                            |
+-------------------------+--------------+------------------------+-----------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- vocabulary\_id
- (vocabulary\_id, end\_date)
- end\_date

## Table: tasks

(NB 1: In the current database, this table is called `task`.) (NB 2: The
description below formerly included a "modified\_by" column, but it has
not (yet) been implemented, so it was removed.)

+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| Column         | Type        | Extra                                         | Notes                                      | Example(s) |
+:===============+:============+:==============================================+:===========================================+:===========+
| id             | integer     | auto\_increment                               | Surrogate key                              | 18         |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| vocabulary\_id | integer     | foreign key references access\_point\_ids(id) | The vocabulary id                          | 2          |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| version\_id    | integer     | foreign key references version\_ids(id)       | The version id                             | 5          |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| params         | text        |                                               |                                            |            |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| status         | varchar(45) |                                               | Enumerated type: SUCCESS, ERROR, EXCEPTION | SUCCESS    |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+
| response       | text        |                                               |                                            |            |
+----------------+-------------+-----------------------------------------------+--------------------------------------------+------------+

Indexes (this is a draft list: refine this!):

- id

## Table: poolparty\_servers

If there ends up being more than one server supported, add some way of
indicating "active" rows. This could be by adding an "active" Boolean
column, or by making this a "temporal" table with start\_date/end\_date
values and adding an associated poolparty\_servers\_ids table.

+----------+--------------+-----------------+-----------------------------------------------------+--------------------------------------+
| Column   | Type         | Extra           | Notes                                               | Example(s)                           |
+:=========+:=============+:================+:====================================================+:=====================================+
| id       | integer      | auto\_increment | Surrogate key                                       | 2                                    |
+----------+--------------+-----------------+-----------------------------------------------------+--------------------------------------+
| api\_url | varchar(255) |                 | The URL of the top of the API.                      | http://ands.poolparty.biz/PoolParty/ |
|          |              |                 | API call selectors are appended to this value.      |                                      |
+----------+--------------+-----------------+-----------------------------------------------------+--------------------------------------+
| username | varchar(45)  |                 | The username to use to connect to the API           | ANDS\_Toolkit                        |
+----------+--------------+-----------------+-----------------------------------------------------+--------------------------------------+
| password | varchar(45)  |                 | The password to use to connect to the API           | aPassword                            |
+----------+--------------+-----------------+-----------------------------------------------------+--------------------------------------+

Indexes (this is a draft list: refine this!):

- id

Populate this table as follows:

``` sql
insert into poolparty_servers(id,api_url,username,password)
  values (1,"hostname","username","password");
-- For example ("pw" is not the real password!):
-- insert into poolparty_servers(id,api_url,username,password) values
--   (1,"https://editor.vocabs.ands.org.au/PoolParty/","ANDS_Toolkit","pw");
```

## Table: registry\_events

See the page
[Vocabulary Registry events](Vocabulary_Registry_events.md) for the
definitive list of all possible types of Registry event.

List of events in the lifecycle of a registry element (i.e., a
vocabulary, or a version, or ...). Used for generating feeds (RSS,
etc.). The element\_type values are taken from an enumerated type
defined in the registry schema (`common-types.xsd`), based on tables
names (i.e., in the plural form). The difficulty: since we have (so far)
gone with element\_type/element\_id, how do we then conveniently get
(say) a list of all events for a vocabulary, i.e., that include the
events for all versions of that vocabulary? This could be done with a
VIEW that does the necessary joins. But how expensive would that be?

+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| Column         | Type         | Extra           | Notes                                                        | Example(s)                 |
+:===============+:=============+:================+:=============================================================+:===========================+
| id             | integer      | auto\_increment | Surrogate key                                                | 2                          |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| element\_type  | varchar(45)  |                 | Enumerated type (registry schema                             | VOCABULARIES\              |
|                |              |                 | `registry-event-element-type`): the type of registry         | VERSIONS\                  |
|                |              |                 | element. Let's say for now that we support temporal          | ACCESS\_POINTS\            |
|                |              |                 | elements only (i.e., with start\_date/end\_date values       | RELATED\_ENTITIES          |
|                |              |                 | and corresponding \_ids tables). That means VOCABULARIES,    |                            |
|                |              |                 | VERSIONS, etc., but not TASKS.                               |                            |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| element\_id    | integer      |                 | The "real" id of the registry element, in the                | 2                          |
|                |              |                 | corresponding table. So, if element\_type=VOCABULARIES,      |                            |
|                |              |                 | this would be a value from the                               |                            |
|                |              |                 | vocabularies.vocabulary\_id column.                          |                            |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| event\_date    | datetime     |                 | Value is in the UTC timezone                                 | 2016-08-15 13:50:47.123468 |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| event\_type    | varchar(45)  |                 | Enumerated type (registry schema                             | CREATED                    |
|                |              |                 | `registry-event-event-type`), e.g., CREATED, DELETED,        |                            |
|                |              |                 | \.... At present, the value is to be interpreted in terms    |                            |
|                |              |                 | of current instances *only*, i.e., not drafts. For           |                            |
|                |              |                 | example, if a vocabulary is "created" first as a draft,      |                            |
|                |              |                 | no registry event is recorded for that. If the draft is      |                            |
|                |              |                 | subsequently published, *that* is recorded as a registry     |                            |
|                |              |                 | event of event\_type CREATED.                                |                            |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| event\_user    | varchar(255) |                 | The user Role ID responsible for creating this row in the    | rwalker                    |
|                |              |                 | table. *Not* (necessarily) the role that owns the            |                            |
|                |              |                 | registry element.                                            |                            |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+
| event\_details | text         |                 | JSON to store everything else. A map of strings to           | { }                        |
|                |              |                 | objects, which are either strings or integers. See           |                            |
|                |              |                 | [Vocabulary Registry events](Vocabulary_Registry_events.md)  |                            |
|                |              |                 | for the keys and values used for each type of event.         |                            |
+----------------+--------------+-----------------+--------------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- (element\_type, element\_id)

## Table: subject\_resolver\_sources

List of subject sources for which we do resolution of IRIs to label (and
possibly notation). Note the relationship between the contents of this
table, and the definition of the configuration
setting $ENV\['vocab\_resolving\_services'\] in the portal's
`global_config.php` . The latter defines SISSVoc endpoints that wrap the
corresponding SPARQL endpoints defined in this table. Note especially
that the values of the keys in the portal definition must match
(including case) the values of the source column of this table. (The
portal definition includes a definition for local that does not specify
anything for IRI resolution; correspondingly, this table does not have a
row for that subject source.)

+--------+---------------+-----------------+-----------------------------------------------------------+----------------------------------------------------------------+
| Column | Type          | Extra           | Notes                                                     | Example(s)                                                     |
+:=======+:==============+:================+:==========================================================+:===============================================================+
| id     | integer       | auto\_increment | Surrogate key                                             | 2                                                              |
+--------+---------------+-----------------+-----------------------------------------------------------+----------------------------------------------------------------+
| source | varchar(10)   |                 | Subject source. These values are also used in the         | - anzsrc-for                                                   |
|        |               |                 | portal's `global_config.php` as keys within the value of  | - anzsrc-seo                                                   |
|        |               |                 | `$ENV['vocab_resolving_services']`.                       | - gcmd                                                         |
+--------+---------------+-----------------+-----------------------------------------------------------+----------------------------------------------------------------+
| iri    | varchar(1023) |                 | IRI of a SPARQL endpoint from which to fetch the details  | - http://localhost/repository/api/sparql/anzsrc-for            |
|        |               |                 | of the subjects.                                          | - http://vocabs.ands.org.au/repository/api/sparql/anzsrc-for   |
+--------+---------------+-----------------+-----------------------------------------------------------+----------------------------------------------------------------+

Indexes (this is a draft list: refine this!):

- id

Populate this table as follows:

``` sql
insert into subject_resolver_sources(source,iri)
  values ('anzsrc-for', 'http://vocabs.ands.org.au/repository/api/sparql/anzsrc-for');
insert into subject_resolver_sources(source,iri)
  values ('anzsrc-seo', 'http://vocabs.ands.org.au/repository/api/sparql/anzsrc-seo');
insert into subject_resolver_sources(source,iri)
  values ('gcmd', 'http://vocabs.ands.org.au/repository/api/sparql/gcmd-sci');
```

## Table: subject\_resolver

List of subjects that we can resolve from a source/IRI to a label, and
possibly a notation.

+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+
| Column   | Type          | Extra           | Notes                                                     | Example(s)                                                |
+==========+===============+=================+===========================================================+===========================================================+
| id       | integer       | auto\_increment | Surrogate key                                             | 2                                                         |
+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+
| source   | varchar(10)   |                 | Subject source                                            | - anzsrc-for                                              |
|          |               |                 |                                                           | - anzsrc-seo                                              |
|          |               |                 |                                                           | - gcmd                                                    |
+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+
| iri      | varchar(1023) |                 | The subject's IRI in the source vocabulary                | http://purl.org/au-research/vocabulary/anzsrc-for/2008/04 |
+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+
| notation | varchar(255)  |                 | The subject's notation, if it has one, or an empty        | 04                                                        |
|          |               |                 | string, if it doesn't                                     |                                                           |
+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+
| label    | text          |                 | The subject's label: typically, this is the value of the  | EARTH SCIENCES                                            |
|          |               |                 | skos:prefLabel property                                   |                                                           |
+----------+---------------+-----------------+-----------------------------------------------------------+-----------------------------------------------------------+

Indexes (this is a draft list: refine this!):

- id
- (source, iri)

## Table: uploads

File uploads.

+--------------+--------------+-----------------+------------------------------------------------------------+------------+
| Column       | Type         | Extra           | Notes                                                      | Example(s) |
+:=============+:=============+:================+:===========================================================+:===========+
| id           | integer      | auto\_increment | Surrogate key                                              | 18         |
+--------------+--------------+-----------------+------------------------------------------------------------+------------+
| modified\_by | varchar(255) |                 | The user Role ID responsible for creating this             | rwalker    |
|              |              |                 | row in the table.                                          |            |
|              |              |                 | *Not* (necessarily) the role that owns the vocabulary.     |            |
+--------------+--------------+-----------------+------------------------------------------------------------+------------+
| owner        | varchar(255) |                 | Role ID taken from dbs\_roles.roles(role\_id);             | ANDS       |
|              |              |                 | either an organisational role or an individual user        |            |
+--------------+--------------+-----------------+------------------------------------------------------------+------------+
| format       | varchar(45)  |                 | The file format: RDF/XML, TTL, N-Triples, ...              | TTL        |
+--------------+--------------+-----------------+------------------------------------------------------------+------------+
| filename     | varchar(255) |                 | The filename of the file as provided at the time           | myfile.ttl |
|              |              |                 | of the upload, but sanitized to eliminate certain          |            |
|              |              |                 | characters and to enforce one extension.                   |            |
|              |              |                 | E.g., "abc 123.4.ttl" becomes "abc\_123\_4.ttl".           |            |
+--------------+--------------+-----------------+------------------------------------------------------------+------------+

Indexes (this is a draft list: refine this!):

- id

# Resource IRI resolution service

See
[Vocabulary resource IRI resolution service](Vocabulary_resource_IRI_resolution_service.md) for
further details about the database tables that support the resource IRI
resolution service.

## Table: resource\_owner\_hosts

NB: there can be multiple rows with the same owner, and there can be
multiple rows with the same host.

+-------------+--------------+-----------------+------------------------------------------------+----------------------------+
| Column      | Type         | Extra           | Notes                                          | Example(s)                 |
+:============+:=============+:================+:===============================================+:===========================+
| id          | int          | auto\_increment | ID for this row of the table; surrogate key    | 1, 2, ...                  |
+-------------+--------------+-----------------+------------------------------------------------+----------------------------+
| start\_date | datetime     |                 | Value is in the UTC timezone                   | 2016-08-15 13:50:46.123468 |
+-------------+--------------+-----------------+------------------------------------------------+----------------------------+
| end\_date   | datetime     |                 | Value is in the UTC timezone                   | 9999-12-01 00:00:00        |
+-------------+--------------+-----------------+------------------------------------------------+----------------------------+
| owner       | varchar(255) |                 | Owner; should be a role name;                  | AODN                       |
|             |              |                 | usually, an organisational role                |                            |
+-------------+--------------+-----------------+------------------------------------------------+----------------------------+
| host        | varchar(255) |                 | Hostname "owned" by this owner                 | vocab.aodn.org.au          |
+-------------+--------------+-----------------+------------------------------------------------+----------------------------+

Indexes:

- id (primary key)

## Table: resource\_map

This table is a map from IRIs to access points. The two columns that
implement this map are `iri` and `access_point_id`. An instance of the
map has three other attributes that qualify that instance:

- Whether or not the (user) role responsible for publishing the access
  point "owns" that IRI, based on the resource\_owner\_hosts table.
- The IRI of the RDF type that represents the resource's type, *or* the
  special IRI corresponding to owl:deprecated, if the resource does not
  have a defined type at that access point.
- Whether or not the access point defines the resource as deprecated
  using the owl:deprecated property.

The "owned" attribute means that it is possible to add to the map *all*
of the resource IRIs used in a vocabulary, while allowing resolution to
be implemented in such a way that prevents inadvertent (or deliberate)
gazumping of the resolution of an IRI by someone other than the "owner"
of an IRI publishing a vocabulary that uses that resource.

+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| Column            | Type          | Extra                  | Notes                                               | Example(s)                                          |
+:==================+:==============+:=======================+:====================================================+:====================================================+
| id                | integer       | auto\_increment        | ID for this row of the table; surrogate key         | 1, 2, ...                                           |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| iri               | varchar(1023) |                        | Resource to be mapped. There is an index            | http://vocab.aodn.org.au/def/organisation/entity/32 |
|                   |               |                        | on this field for quick *lookups*.                  |                                                     |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| access\_point\_id | integer       | foreign key references | Access point to use to resolve the resource.        | 45, 67, ...                                         |
|                   |               | access\_point\_ids(id) | Must be an access point with type="SISSVOC".        |                                                     |
|                   |               |                        | There is an index on this field for                 |                                                     |
|                   |               |                        | quick *deletes*.                                    |                                                     |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| owned             | boolean       |                        | Is this resource owned by the owner of this         | TRUE                                                |
|                   |               |                        | vocabulary? All resources are included in           |                                                     |
|                   |               |                        | the map; but for some resolution modes, only        |                                                     |
|                   |               |                        | those that are "owned" will be resolved.            |                                                     |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| resource\_type    | varchar(1023) |                        | The IRI of the resource type if available,          | http://www.w3.org/2004/02/skos/core\#Concept        |
|                   |               |                        | or http://www.w3.org/2002/07/owl\#deprecated        |                                                     |
|                   |               |                        | if there is no known type, and this is a            |                                                     |
|                   |               |                        | deprecated resource                                 |                                                     |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+
| deprecated        | boolean       |                        | Is this a deprecated resource? True if              | FALSE                                               |
|                   |               |                        | there is a triple "iri owl:deprecated true".        |                                                     |
+-------------------+---------------+------------------------+-----------------------------------------------------+-----------------------------------------------------+

Indexes:

- id (primary key)
- iri(191)
- access\_point\_id

Note the key length for the ix\_resource\_map\_iri index on the "iri"
field: MySQL 5.6 requires a key length in this case. (In MySQL up to
version 5.6, index fields are limited to 767 bytes. In utf8mb4 encoding,
that means 191 characters.)

# Subscriptions and notifications

The following classes represent subscribers, and subscriptions to
notifications about registry events.

Note that we have a subscribers table that has top-level data about a
subscriber. For now, there is only notification by email. But we allow
for future expansion of the notification types by putting email
addresses in a separate table.

## Table: subscribers

This table is for representing top-level data about subscribers to
notifications about registry events.

+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| Column         | Type         | Extra               | Notes                                                   | Example(s)                 |
+:===============+:=============+:====================+:========================================================+:===========================+
| id             | integer      | auto\_increment     | Surrogate key                                           | 18                         |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| start\_date    | datetime     |                     | Value is in the UTC timezone                            | 2016-08-15 13:50:47.123468 |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| end\_date      | datetime     |                     | Value is in the UTC timezone                            | 9999-12-01 00:00:00        |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| subscriber\_id | integer      | foreign key         | The "real" subscriber id                                | 2                          |
|                |              | references          |                                                         |                            |
|                |              | subscriber\_ids(id) |                                                         |                            |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| modified\_by   | varchar(255) |                     | The user Role ID responsible for creating this          | SYSTEM                     |
|                |              |                     | row in the table. *Not* (necessarily) the role          |                            |
|                |              |                     | that owns the subscriber: indeed, since subscribers     |                            |
|                |              |                     | are not (currently) linked to user roles,               |                            |
|                |              |                     | this will probably be SYSTEM for now.                   |                            |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+
| token          | varchar(45)  |                     | The subscriber's token, used to manage subscriptions.   | 2\_rf6FlQkBj               |
|                |              |                     | Because we are using pac4j for authentication,          |                            |
|                |              |                     | the token must be self-contained, i.e., contain         |                            |
|                |              |                     | everything needed to identify the subscriber.           |                            |
|                |              |                     | In practice, the subscriber\_id must be included        |                            |
|                |              |                     | in the token value. In the example given,               |                            |
|                |              |                     | the subscriber\_id is separated from the                |                            |
|                |              |                     | "password"-like component by an underscore.             |                            |
+----------------+--------------+---------------------+---------------------------------------------------------+----------------------------+

Indexes (this is a draft list: refine this!):

- id
- subscriber\_id
- (subscriber\_id, end\_date)
- end\_date

## Table: subscriber\_email\_addresses

This table is for representing the email addresses of subscribers to
notifications about registry events.

+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| Column                         | Type         | Extra                               | Notes                                    | Example(s)                 |
+:===============================+:=============+:====================================+:=========================================+:===========================+
| id                             | integer      | auto\_increment                     | Surrogate key                            | 18                         |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| start\_date                    | datetime     |                                     | Value is in the UTC timezone             | 2016-08-15 13:50:47.123468 |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| end\_date                      | datetime     |                                     | Value is in the UTC timezone             | 9999-12-01 00:00:00        |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| subscriber\_email\_address\_id | integer      | foreign key references              | The "real" subscriber email address id   | 2                          |
|                                |              | subscriber\_email\_address\_ids(id) |                                          |                            |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| subscriber\_id                 | integer      | foreign key references              |                                          |                            |
|                                |              | subscriber\_ids(id)                 |                                          |                            |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+
| email\_address                 | varchar(255) |                                     | The subscriber's email address           | rwalker\@myhost.org        |
+--------------------------------+--------------+-------------------------------------+------------------------------------------+----------------------------+

Indexes:

- id (primary key)
- ix\_subscriber\_email\_addresses\_email\_address\_end\_date:
  (email\_address, end\_date)

## Table: subscriptions

This table is for representing subscriptions to notifications about
registry events. Draft rows could represent "pending" subscriptions,
e.g., needing confirmation from the user.

+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| Column                      | Type         | Extra                 | Notes                                                       | Example(s)                 |
+:============================+:=============+:======================+:============================================================+:===========================+
| id                          | integer      | auto\_increment       | Surrogate key                                               | 18                         |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| start\_date                 | datetime     |                       | Value is in the UTC timezone                                | 2016-08-15 13:50:47.123468 |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| end\_date                   | datetime     |                       | Value is in the UTC timezone                                | 9999-12-01 00:00:00        |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| subscription\_id            | integer      | foreign key           | The "real" subscription id                                  | 2                          |
|                             |              | references            |                                                             |                            |
|                             |              | subscription\_ids(id) |                                                             |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| subscriber\_id              | integer      | foreign key           | For notifications to be sent, there must be an entry        | 3                          |
|                             |              | references            | in the appropriate table for the notification\_mode.        |                            |
|                             |              | subscriber\_ids(id)   | For notification\_mode=EMAIL, that means that there         |                            |
|                             |              |                       | must be an entry in the subscriber\_email\_addresses        |                            |
|                             |              |                       | table which has start\_date/end\_date values                |                            |
|                             |              |                       | consistent with the start\_date/end\_date                   |                            |
|                             |              |                       | values of this entry.                                       |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| modified\_by                | varchar(255) |                       | The user Role ID responsible for creating this row          | SYSTEM                     |
|                             |              |                       | in the table. *Not* (necessarily) the role                  |                            |
|                             |              |                       | that owns the subscriber: indeed, since                     |                            |
|                             |              |                       | subscribers are not (currently) linked to                   |                            |
|                             |              |                       | user roles, this will probably be SYSTEM for now.           |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| notification\_mode          | varchar(45)  |                       | The mode by which the notification is to be                 | EMAIL                      |
|                             |              |                       | delivered. Enumerated type: EMAIL                           |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| notification\_element\_type | varchar(45)  |                       | The type of notification being subscribed to.               | VOCABULARY                 |
|                             |              |                       | Enumerated type: SYSTEM, OWNER, VOCABULARY                  |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| notification\_element\_id   | integer      |                       | The id of the element of the element type which             | 2                          |
|                             |              |                       | is being subscribed to. If the element type does            |                            |
|                             |              |                       | not distinguish instances, then the value 0 is used.        |                            |
|                             |              |                       |                                                             |                            |
|                             |              |                       | - If notification\_element\_type = SYSTEM,                  |                            |
|                             |              |                       |   0                                                         |                            |
|                             |              |                       | - If notification\_element\_type = OWNER,                   |                            |
|                             |              |                       |   an owner\_id                                              |                            |
|                             |              |                       | - If notification\_element\_type = VOCABULARY,              |                            |
|                             |              |                       |   a vocabulary\_id                                          |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| last\_notification          | datetime     |                       | Value is in the UTC timezone. The date/time of the          | 2018-03-15 13:50:47.123468 |
|                             |              |                       | last successful sending of a notification                   |                            |
|                             |              |                       | for this subscription.                                      |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+
| data                        | text         |                       | JSON to store everything else. Future work could            | {}                         |
|                             |              |                       | be to use this field to indicate                            |                            |
|                             |              |                       | notification-mode-specific configuration.                   |                            |
|                             |              |                       |                                                             |                            |
|                             |              |                       | For now:                                                    |                            |
|                             |              |                       |                                                             |                            |
|                             |              |                       | - creator: the role that created this                       |                            |
|                             |              |                       |   subscription. (Immediately after creation,                |                            |
|                             |              |                       |   this will be equal to the value of the                    |                            |
|                             |              |                       |   modified\_by column. But if this                          |                            |
|                             |              |                       |   subscription is deleted, modified\_by                     |                            |
|                             |              |                       |   will be set to SYSTEM.)                                   |                            |
|                             |              |                       |                                                             |                            |
|                             |              |                       | Future (?): For notification\_mode = EMAIL:                 |                            |
|                             |              |                       |                                                             |                            |
|                             |              |                       | - notification frequency (weekly, monthly)                  |                            |
+-----------------------------+--------------+-----------------------+-------------------------------------------------------------+----------------------------+

Indexes:

- id (primary key)
- ix\_subscriptions\_notification\_mode\_end\_date: (notification\_mode,
  end\_date)

## Table: owners

This table is a helper table for use with the notification
subsystem. Because the subscriptions.notification\_element\_id is an
integer, and because one of the possible values of
subscriptions.notification\_element\_type is OWNER, we need an integer
for each owner. Future work could be to make this into one of the "main"
tables, i.e., by adding a separate owner\_ids table, and adding id,
start\_date, and end\_date columns to the owners table.

+-----------+--------------+------------------+----------------------------------------------------------+------------+
| Column    | Type         | Extra            | Notes                                                    | Example(s) |
+:==========+:=============+:=================+:=========================================================+:===========+
| owner\_id | integer      | auto\_increment, | Owner id, which can be used as the value of              | 18         |
|           |              | primary key,     | subscriptions.notification\_element\_id,                 |            |
|           |              | index            | if notification\_element\_type is OWNER                  |            |
+-----------+--------------+------------------+----------------------------------------------------------+------------+
| owner     | varchar(255) |                  | Role ID taken from dbs\_roles.roles(role\_id);           | ANDS       |
|           |              |                  | either an organisational role or an individual user.     |            |
|           |              |                  | There is a unique constraint on this column.             |            |
|           |              |                  | (The constraint is implied by the addition               |            |
|           |              |                  | of an index on this column.)                             |            |
+-----------+--------------+------------------+----------------------------------------------------------+------------+

Indexes:

- owner\_id (primary key)
- ix\_owners\_owner: (owner)

# Integrity constraints

This section specifies database integrity constraints not otherwise
specified in the previous section.

- Need to pay attention to the entries in the previous section of the
  form "There must be an entry in the xyz table which has
  start\_date/end\_date values consistent with the start\_date/end\_date
  values of this entry". These can be implemented in a number of ways:
    - As database triggers on insert/update. The coding of triggers
      tends to be database-specific.
    - As JPA entity listeners. This is underway. See the VersionListener
      class for an example.
- It turns out that putting constraints at the level of the DDL (i.e.,
  table and index creation SQL commands) is problematic because JPA can
  re-order statements within a transaction. See, e.g., 
  <https://vladmihalcea.com/hibernate-facts-knowing-flush-operations-order-matters/> for
  an explanation. If we end up doing this sort of thing, we will need to
  put calls to `em.flush()` in various places. See, e.g., the comments
  and commented-out changesets for triggers in
  `src/main/db/changelog/registry-0001.xml`, and the comments for the
  changeset `0002-vocabularies_vocabulary_id_end_date-createIndex`
  in `src/main/db/changelog/registry-0002.xml`.


