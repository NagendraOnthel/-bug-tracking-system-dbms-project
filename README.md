# Bug Tracking System - DBMS Lab Project

A relational **Bug Tracking System database** built with **Microsoft SQL Server** and **SQL Server Management Studio (SSMS)**. The project models the complete software-bug lifecycle, from reporting and assignment to resolution, verification, reopening, closure, and audit history.

The focus of this project is database design, normalization, data integrity, advanced SQL querying, stored procedures, triggers, transaction control, and role-based workflow enforcement.

## Project Overview

The system supports four roles:

- **Admin** - manages users and system-level data.
- **Project Manager** - manages projects, memberships, and bug assignments.
- **Developer** - works on assigned bugs and updates progress.
- **Tester** - reports bugs and verifies resolved bugs.

### Bug Workflow

`Open -> Assigned -> In Progress -> Resolved -> Closed`

If verification fails:

`Resolved -> Reopened -> In Progress -> Resolved -> Closed`

The workflow is enforced at the database level using triggers and role checks.

## Key Features

- 9-table normalized relational database design
- Primary keys, composite keys, foreign keys, UNIQUE, NOT NULL, DEFAULT, and CHECK constraints
- 3NF normalization and BCNF-consistent design under the intended dependencies
- Role-based bug reporting and assignment rules
- Complete bug status lifecycle and audit history
- CRUD operations using INSERT, SELECT, UPDATE, and DELETE
- Aggregate queries using COUNT, SUM, AVG, MIN, MAX, GROUP BY, and HAVING
- INNER, LEFT, RIGHT, SELF, FULL OUTER, and multi-table joins
- Scalar and nested subqueries using IN, EXISTS, NOT EXISTS, ANY, ALL, and derived tables
- Stored procedures with validation and OUTPUT parameters
- Triggers for workflow validation and audit logging
- Transactions using BEGIN TRANSACTION, COMMIT, ROLLBACK, SAVE TRANSACTION, and TRY/CATCH
- Sample projects, users, categories, bugs, comments, and attachments for testing

## Database Schema

The database contains the following tables:

| Table | Purpose |
|---|---|
| `Roles` | Stores system roles |
| `Users` | Stores users and their assigned roles |
| `Projects` | Stores project information |
| `ProjectMembers` | Resolves the many-to-many relationship between projects and users |
| `Categories` | Stores bug categories |
| `Bugs` | Core bug records, assignment, severity, priority, and status |
| `BugComments` | Stores comments added to bugs |
| `BugStatusHistory` | Maintains an audit trail of status changes |
| `BugAttachments` | Stores attachment metadata for bugs |

## ERD

Assets/erd.png

## Design Review

(https://github.com/NagendraOnthel/-bug-tracking-system-dbms-project/blob/main/Assets/design-review.png)

## Stored Procedures

### `spAddBug`
Creates a new bug after validating the project, reporter, category, Tester role, and project membership.

### `spAssignBug`
Allows a Project Manager to assign a bug only to a Developer who belongs to the same project.

### `spGetProjectBugCount`
Returns the total number of bugs for a selected project through an OUTPUT parameter.

## Triggers

### `trgBugStatusAudit`
- Validates permitted bug status transitions
- Ensures only a Tester can close a resolved bug
- Inserts every permitted status change into `BugStatusHistory`

### `trgValidateBugAssignment`
- Ensures only Developers can be assigned to bugs
- Ensures the assigned Developer is a member of the related project

## Technologies

- Microsoft SQL Server Express
- SQL Server Management Studio (SSMS)
- T-SQL
- Relational Database Design
- ERD / Database Modeling

## Repository Structure

```text
bug-tracking-system-dbms/
├── assets/
│   ├── design-review.png
│   └── erd.png
├── database/
│   ├── project.sql
│   └── queries.sql
├── .gitignore
└── README.md
```

## How to Run

1. Install **Microsoft SQL Server Express** and **SQL Server Management Studio (SSMS)**.
2. Open `database/project.sql` in SSMS.
3. Execute the script to create the `BugTrackDatabase` database, tables, constraints, stored procedures, triggers, sample data, and query demonstrations.
4. Use `database/queries.sql` to review or execute the main SQL feature demonstrations separately.
5. Review the project documentation in the `docs/` folder for the ERD, normalization, design review, workflow, and sample outputs.

> **Note:** The users and passwords included in the SQL script are fictional sample data created only for an academic database demonstration. A production application should never store plaintext passwords; password hashing and secure authentication would be required.

## DBMS Concepts Demonstrated

This project demonstrates practical use of:

- Relational modeling and functional dependencies
- Database normalization
- Referential and domain integrity
- Composite keys and many-to-many relationships
- Stored procedures and parameter validation
- Trigger-based business rules
- Audit logging
- Transaction management and rollback
- Advanced joins and subqueries
- Aggregation and reporting queri

This repository is intended as an academic and portfolio project demonstrating practical SQL Server database design and DBMS concepts.
