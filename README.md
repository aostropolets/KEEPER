KEEPER
==============
Introduction
============

An R package review patient profiles for phenotype validation. 


Features
========

- From an instantiated cohort, identifies specified number of random persons. It also allows for non random selection by specifying a set of personId as input.
- Extracts person level data for each person from the common data model, and constructs a results object in rds form. This rds object has person level data with personId and dates.
- Accepts a set of configurable parameters for the shiny application. This parameters will be chosen in the shiny app. e.g. regular expression.
- Allows additional de-identification using two optional mechanisms (shift dates and replace OMOP personId with a new random id). Shift date: shifts all dates so that the first observation_period_start_date for a person is set to January 1st 2000, and all other dates are shifted in relation to this date. Also creates and replaces the source personId with a new randomly generated id.


How to use
==========

- Go the output location in your file browser (e.g. windows file explorer in a Windows computer) and start 'KEEPER.Rproj'.
- In R console now run renv::restore() to enable renv. This will download all required packages and dependencies and set up the run environment. 
- run createKEEPER() with approapriate parameters (see an example in R/createKEEPER.R) to create a csv file with patient profiles

Technology
==========
KEEPER is an R package.

System Requirements
===================
Requires R (version 3.6.0 or higher). 

Installation
=============
1. See the instructions [here](https://ohdsi.github.io/Hades/rSetup.html) for configuring your R environment, including RTools and Java.

2. In R, use the following commands to download and install CohortExplorer:

  ```r
  install.packages("remotes")
  remotes::install_github("aostropolets/KEEPER")
  ```

User Documentation
==================
TBD

Support
=======
TBD

Contributing
============
TBD

License
=======
KEEPER is licensed under Apache License 2.0

Development
===========
KEEPER is being developed in R Studio.

### Development status

KEEPER is under development.
