---
title: 'Vocabulary Registry design diagrams'
output:
  html:
    to: html
    standalone: true
    css: pandoc.css
comment: |
  You can use panrun on this file, to make HTML:
  panrun Vocabulary_Registry_design_diagrams.md > Vocabulary_Registry_design_diagrams.html
  To generate HTML using pandoc, you'll need these settings:
  pandoc -s --css ../css/pandoc.css -f markdown -t html Vocabulary_Registry_design_diagrams.md > Vocabulary_Registry_design_diagrams.html
  To generate PDF:
  pandoc -s -f markdown -o Vocabulary_Registry_design_diagrams.pdf Vocabulary_Registry_design_diagrams.md
  Or, starting from previously-generated HTML:
  wkhtmltopdf --zoom 2 --user-style-sheet ../conf/pandoc-wkhtmltopdf.css Vocabulary_Registry_design_diagrams.html Vocabulary_Registry_design_diagrams.pdf

...


Attached are some diagrams showing the relationships between the
essential "model" entities of the registry.

- Diagram showing the entity classes "collapsed", i.e., no attributes
  or methods are shown.
- Diagram showing the entity classes. Some attributes are shown: ids,
  status, and some other important attributes.
- Diagram showing the classes that implement the model subsystem as
  part of the publication workflow. See
  [Vocabulary Registry model subsystem](Vocabulary_Registry_model_subsystem)
  for details.
- Diagram showing the top-level classes that implement the workflow,
  including classes that describe tasks. See
  [Vocabulary Registry Workflow subsystem design](Vocabulary_Registry_Workflow_subsystem_design)
  for details.
- Sequence diagram for the scenario of updating the current instance
  of a vocabulary. Shows the interactions between many subsystems:
  API, model, workflow, database.
- Diagram showing the classes that implement registry events,
  subscriptions, and notifications. See
  [Vocabulary Registry events](https://intranet.ands.org.au/pages/viewpage.action?spaceKey=PROJ&title=Vocabulary+Registry+events)
  and
  [Vocabulary subscription and notification subsystem](Vocabulary_subscription_and_notification_subsystem)
  for details.
- Diagram showing the classes that implement the fixed-time model
  subsystem used by the notification subsystem. See
  [Vocabulary subscription and notification subsystem](Vocabulary_subscription_and_notification_subsystem)
  and
  [Vocabulary fixed-time vocabulary model subsystem](Vocabulary_fixed-time_vocabulary_model_subsystem)
  for details.

UML diagrams have been created using UMLet (<http://www.umlet.com/>).


+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Description                                                                         | Link                                                                                |
+:====================================================================================+:====================================================================================+
| Vocabulary model classes; UMLet format                                              | [vocabulary-model.uxf](../diagrams/design/vocabulary-model.uxf)                     |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Vocabulary model classes; PDF format                                                | [vocabulary-model.pdf](../diagrams/design/vocabulary-model.pdf)                     |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Just the main entity classes; no attributes or methods; UMLet format                | [vocabs-just-classes.uxf](../diagrams/design/vocabs-just-classes.uxf)               |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Just the main entity classes; no attributes or methods; PDF format                  | [vocabs-just-classes.pdf](../diagrams/design/vocabs-just-classes.pdf)               |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Just the main entity classes; main attributes shown; UMLet format                   | [vocabs-with-attributes.uxf](../diagrams/design/vocabs-with-attributes.uxf)         |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Just the main entity classes; main attributes shown; PDF format                     | [vocabs-with-attributes.pdf](../diagrams/design/vocabs-with-attributes.pdf)         |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Vocabulary workflow classes; UMLet format                                           | [vocabulary-workflow.uxf](../diagrams/design/vocabulary-workflow.uxf)               |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Vocabulary workflow classes; PDF format                                             | [vocabulary-workflow.pdf](../diagrams/design/vocabulary-workflow.pdf)               |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Sequence diagram of updating a current instance; UMLet format                       | [update-current-instance.uxf](../diagrams/design/update-current-instance.uxf)       |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Sequence diagram of updating a current instance; PDF format                         | [update-current-instance.pdf](../diagrams/design/update-current-instance.pdf)       |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Fixed-time vocabulary model classes; UMLet format                                   | [vocabulary-model-fixedtime.uxf](../diagrams/design/vocabulary-model-fixedtime.uxf) |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Fixed-time vocabulary model classes; PDF format                                     | [vocabulary-model-fixedtime.pdf](../diagrams/design/vocabulary-model-fixedtime.pdf) |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Registry events, subscriptions, notifications; UMLet format                         | [vocabs-registry-events.uxf](../diagrams/design/vocabs-registry-events.uxf)         |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+
| Registry events, subscriptions, notifications; PDF format                           | [vocabs-registry-events.pdf](../diagrams/design/vocabs-registry-events.pdf)         |
+-------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------+

