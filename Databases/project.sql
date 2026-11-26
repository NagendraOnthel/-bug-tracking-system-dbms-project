-- Bug Tracking System - DBMS Lab Project
-- Microsoft SQL Server / SQL Server Management Studio (SSMS)
-- Academic project: sample data is included for demonstration only.

create database BugTrackDatabase;
use BugTrackDatabase;

create table Roles(
RoleID int identity(1,1) constraint PKRoles primary key,
RoleName varchar(30) not null constraint UQRolesRoleName unique
);

create table Users(
UserID int identity(1,1) constraint PKUsers primary key,
Name varchar(100) not null,
Email varchar(100) not null constraint UQUsersEmail unique,
[Password] varchar(255) not null,
RoleID int not null,
CreatedAt datetime not null constraint DFUsersCreatedAt default getdate(),
constraint FKUsersRoles foreign key(RoleID) references Roles(RoleID)
);

create table Projects(
ProjectID int identity(1,1) constraint PKProjects primary key,
ProjectName varchar(100) not null constraint UQProjectsProjectName unique,
[Description] varchar(500),
StartDate date not null,
EndDate date,
[Status] varchar(30) not null constraint DFProjectsStatus default 'Active',
constraint CKProjectsDates check(EndDate is null or EndDate>=StartDate),
constraint CKProjectsStatus check([Status] in('Planned','Active','Completed','On Hold'))
);

create table ProjectMembers(
ProjectID int not null,
UserID int not null,
JoinedDate date not null constraint DFProjectMembersJoinedDate default convert(date,getdate()),
constraint PKProjectMembers primary key(ProjectID,UserID),
constraint FKProjectMembersProjects foreign key(ProjectID) references Projects(ProjectID),
constraint FKProjectMembersUsers foreign key(UserID) references Users(UserID)
);

create table Categories(
CategoryID int identity(1,1) constraint PKCategories primary key,
CategoryName varchar(50) not null constraint UQCategoriesCategoryName unique
);

create table Bugs(
BugID int identity(1001,1) constraint PKBugs primary key,
ProjectID int not null,
ReportedBy int not null,
AssignedTo int,
CategoryID int not null,
Title varchar(200) not null,
[Description] varchar(1000) not null,
Severity varchar(20) not null,
Priority varchar(20) not null,
[Status] varchar(20) not null constraint DFBugsStatus default 'Open',
ReportedDate datetime not null constraint DFBugsReportedDate default getdate(),
ResolvedDate datetime,
constraint FKBugsProjects foreign key(ProjectID) references Projects(ProjectID),
constraint FKBugsReporter foreign key(ReportedBy) references Users(UserID),
constraint FKBugsAssignee foreign key(AssignedTo) references Users(UserID),
constraint FKBugsCategories foreign key(CategoryID) references Categories(CategoryID),
constraint CKBugsSeverity check(Severity in('Low','Medium','High','Critical')),
constraint CKBugsPriority check(Priority in('Low','Medium','High','Critical')),
constraint CKBugsStatus check([Status] in('Open','Assigned','In Progress','Resolved','Reopened','Closed')),
constraint CKBugsResolvedDate check(ResolvedDate is null or ResolvedDate>=ReportedDate)
);

create table BugComments(
CommentID int identity(1,1) constraint PKBugComments primary key,
BugID int not null,
UserID int not null,
CommentText varchar(1000) not null,
CommentDate datetime not null constraint DFBugCommentsDate default getdate(),
constraint FKBugCommentsBugs foreign key(BugID) references Bugs(BugID),
constraint FKBugCommentsUsers foreign key(UserID) references Users(UserID)
);

create table BugStatusHistory(
HistoryID int identity(1,1) constraint PKBugStatusHistory primary key,
BugID int not null,
OldStatus varchar(20),
NewStatus varchar(20) not null,
ChangedBy int not null,
ChangedAt datetime not null constraint DFBugStatusHistoryDate default getdate(),
constraint FKBugStatusHistoryBugs foreign key(BugID) references Bugs(BugID),
constraint FKBugStatusHistoryUsers foreign key(ChangedBy) references Users(UserID),
constraint CKBugStatusHistoryNewStatus check(NewStatus in('Open','Assigned','In Progress','Resolved','Reopened','Closed')),
constraint CKBugStatusHistoryOldStatus check(OldStatus is null or OldStatus in('Open','Assigned','In Progress','Resolved','Reopened','Closed'))
);

create table BugAttachments(
AttachmentID int identity(1,1) constraint PKBugAttachments primary key,
BugID int not null,
FileName varchar(255) not null,
FilePath varchar(500) not null,
UploadedBy int not null,
UploadedAt datetime not null constraint DFBugAttachmentsDate default getdate(),
constraint FKBugAttachmentsBugs foreign key(BugID) references Bugs(BugID),
constraint FKBugAttachmentsUsers foreign key(UploadedBy) references Users(UserID)
);


-- Database procedures, triggers, and schema demonstrations
alter table BugComments add IsEdited bit null;
alter table BugComments drop column IsEdited;


-- Stored Procedure 1: Add Bug
go
create procedure spAddBug
@ProjectID int,
@ReportedBy int,
@CategoryID int,
@Title varchar(200),
@Description varchar(1000),
@Severity varchar(20),
@Priority varchar(20),
@NewBugID int output
as
begin

set nocount on;

if not exists(select 1 from Projects where ProjectID=@ProjectID)
throw 50001,'Project does not exist.',1;

if not exists(select 1 from Users where UserID=@ReportedBy)
throw 50002,'Reporter does not exist.',1;

if not exists(select 1 from Categories where CategoryID=@CategoryID)
throw 50003,'Category does not exist.',1;

if not exists(
select 1
from Users u
join Roles r on u.RoleID=r.RoleID
where u.UserID=@ReportedBy and r.RoleName='Tester'
)
throw 50004,'Only a Tester can report a bug.',1;

if not exists(
select 1
from ProjectMembers
where ProjectID=@ProjectID and UserID=@ReportedBy
)
throw 50005,'Reporter is not a member of the project.',1;

insert into Bugs(ProjectID,ReportedBy,CategoryID,Title,[Description],Severity,Priority,[Status])
values(@ProjectID,@ReportedBy,@CategoryID,@Title,@Description,@Severity,@Priority,'Open');

set @NewBugID=convert(int,scope_identity());
end;



-- Stored Procedure 2: Assign Bug
go
create procedure spAssignBug
@BugID int,
@DeveloperID int
as
begin

set nocount on;

declare @CurrentUserID int=try_convert(int,session_context(N'UserID'));

if @CurrentUserID is null
throw 50006,'Set the Project Manager UserID in SESSION_CONTEXT before assigning a bug.',1;

if not exists(
select 1
from Users u
join Roles r on u.RoleID=r.RoleID
where u.UserID=@CurrentUserID and r.RoleName='Project Manager'
)
throw 50007,'Only a Project Manager can assign a bug.',1;

if not exists(select 1 from Bugs where BugID=@BugID)
throw 50008,'Bug does not exist.',1;

if not exists(
select 1
from Users u
join Roles r on u.RoleID=r.RoleID
where u.UserID=@DeveloperID and r.RoleName='Developer'
)
throw 50009,'Only a Developer can be assigned.',1;

if not exists(
select 1
from Bugs b
join ProjectMembers pm on b.ProjectID=pm.ProjectID
where b.BugID=@BugID and pm.UserID=@DeveloperID
)
throw 50010,'Developer is not a member of this project.',1;

update Bugs
set AssignedTo=@DeveloperID,[Status]=case when [Status]='Open' then 'Assigned' else [Status] end
where BugID=@BugID;
end



-- Stored Procedure 3: Get Project Bug Count
go
create procedure spGetProjectBugCount
@ProjectID int,
@BugCount int output
as
begin

set nocount on;

select @BugCount=count(*) from Bugs
where ProjectID=@ProjectID;
end;



-- Trigger 1: Validate status transitions and maintain audit history
go
create trigger trgBugStatusAudit
on Bugs
after update
as
begin

set nocount on;

if exists(
select 1
from inserted i
join deleted d on i.BugID=d.BugID
where d.[Status]<>i.[Status]
and not(
(d.[Status]='Open' and i.[Status]='Assigned') or
(d.[Status]='Assigned' and i.[Status]='In Progress') or
(d.[Status]='In Progress' and i.[Status]='Resolved') or
(d.[Status]='Resolved' and i.[Status]='Closed') or
(d.[Status]='Resolved' and i.[Status]='Reopened') or
(d.[Status]='Reopened' and i.[Status]='In Progress')
)
)
begin
rollback transaction;
throw 50011,'Invalid bug status transition.',1;
end;

if exists(
select 1
from inserted i
join deleted d on i.BugID=d.BugID
where d.[Status]='Resolved' and i.[Status]='Closed'
and not exists(
select 1
from Users u
join Roles r on u.RoleID=r.RoleID
where u.UserID=isnull(try_convert(int,session_context(N'UserID')),0)
and r.RoleName='Tester'
)
)

begin
rollback transaction;
throw 50012,'Only a Tester can verify and close a resolved bug.',1;
end;

insert into BugStatusHistory(BugID,OldStatus,NewStatus,ChangedBy,ChangedAt)
select i.BugID,d.[Status],i.[Status],isnull(try_convert(int,session_context(N'UserID')),i.ReportedBy),getdate()
from inserted i
join deleted d on i.BugID=d.BugID
where d.[Status]<>i.[Status];
end;



-- Trigger 2: Validate bug assignment rules
go
create trigger trgValidateBugAssignment
on Bugs
after insert,update
as
begin

set nocount on;

if exists(
select 1
from inserted i
join Users u on i.AssignedTo=u.UserID
join Roles r on u.RoleID=r.RoleID
where i.AssignedTo is not null and r.RoleName<>'Developer'
)

begin
rollback transaction;
throw 50013,'Only a Developer can be assigned to a bug.',1;
end;

if exists(
select 1
from inserted i
where i.AssignedTo is not null
and not exists(
select 1
from ProjectMembers pm
where pm.ProjectID=i.ProjectID and pm.UserID=i.AssignedTo
)
)

begin
rollback transaction;
throw 50014,'Assigned developer must be a member of the project.',1;
end;
end;


-- Sample data

insert into Roles(RoleName) values('Admin'),('Project Manager'),('Developer'),('Tester');

insert into Users(Name,Email,[Password],RoleID) values
('Ameen Khan','ameen.khan@bugtrack.local','Ameen@123',1),
('Ghulamullah Ahmed','ghulamullah.ahmed@bugtrack.local','Ghulam@123',2),
('Aqsa Shahzad','aqsa.shahzad@bugtrack.local','Aqsa@123',4),
('Bahzad Ali','bahzad.ali@bugtrack.local','Bahzad@123',3),
('Iqra Noor','iqra.noor@bugtrack.local','Iqra@123',4),
('Azam Khan','azam.khan@bugtrack.local','Azam@123',3),
('Noor Fatima','noor.fatima@bugtrack.local','Noor@123',3),
('Sidra Ahmed','sidra.ahmed@bugtrack.local','Sidra@123',4),
('Bisma Khan','bisma.khan@bugtrack.local','Bisma@123',3),
('Hammad Raza','hammad.raza@bugtrack.local','Hammad@123',2),
('Muhammad Ali','muhammad.ali@bugtrack.local','Ali@123',3);

insert into Projects(ProjectName,[Description],StartDate,EndDate,[Status]) values
('E-Commerce Web Portal','Online shopping platform for QA.','2026-01-10',null,'Active'),
('University Portal','University student and faculty portal.','2026-02-01',null,'Active'),
('Mobile Banking App','Mobile banking application under QA.','2026-01-20',null,'On Hold');

insert into Categories(CategoryName) values
('Authentication'),
('UI'),
('Database'),
('Performance'),
('Security'),
('API'),
('Payment');

insert into ProjectMembers(ProjectID,UserID,JoinedDate) values
(1,2,'2026-01-10'),
(1,3,'2026-01-10'),
(1,4,'2026-01-11'),
(1,5,'2026-01-11'),
(1,6,'2026-01-12'),
(1,11,'2026-01-12'),
(2,3,'2026-02-01'),
(2,7,'2026-02-01'),
(2,8,'2026-02-02'),
(2,9,'2026-02-02'),
(2,10,'2026-02-01'),
(2,11,'2026-02-03'),
(3,2,'2026-01-20'),
(3,4,'2026-01-21'),
(3,5,'2026-01-21'),
(3,6,'2026-01-22'),
(3,8,'2026-01-22'),
(3,11,'2026-01-23');

insert into Bugs(ProjectID,ReportedBy,AssignedTo,CategoryID,Title,[Description],Severity,Priority,[Status]) values
(1,3,4,1,'Login fails with valid credentials','Valid credentials sometimes show an invalid login message.','High','Critical','Assigned'),
(1,5,6,2,'Product image overlaps price','Image overlaps price on small screens.','Medium','Medium','In Progress'),
(1,3,null,3,'Order history query is slow','Order history is slow for large accounts.','High','High','Open'),
(2,8,7,1,'Password reset email not sent','Reset request completes but email is not received.','High','High','Resolved'),
(2,3,9,4,'Dashboard loads slowly','Dashboard takes more than ten seconds.','Medium','High','In Progress'),
(3,5,null,7,'Payment confirmation not displayed','Payment succeeds but confirmation is not displayed.','Critical','Critical','Open'),
(3,8,11,5,'Session timeout issue','Session remains active longer than expected.','High','High','Reopened'),
(1,5,6,6,'Product API returns duplicate records','Product endpoint occasionally duplicates records.','Medium','High','Closed');

insert into BugComments(BugID,UserID,CommentText) values
(1001,3,'Login issue reproduced on Chrome and Edge.'),
(1001,4,'Authentication validation is being checked.'),
(1002,6,'Responsive layout needs a small CSS fix.'),
(1003,3,'Slow query issue reproduced with a large account.'),
(1004,7,'Reset email settings have been corrected.'),
(1005,9,'Dashboard query and loading time are being checked.'),
(1006,5,'Payment completed but confirmation was not shown.'),
(1007,11,'Session timeout configuration needs review.'),
(1008,6,'Duplicate API record issue fixed and verified.');

insert into BugAttachments(BugID,FileName,FilePath,UploadedBy) values
(1001,'login_error.png','/attachments/1001/login_error.png',3),
(1002,'product_overlap.png','/attachments/1002/product_overlap.png',6),
(1003,'query_plan.txt','/attachments/1003/query_plan.txt',3),
(1006,'payment_log.txt','/attachments/1006/payment_log.txt',5);


-- Query demonstrations

select count(*) as TotalBugs from Bugs;

select [Status],count(*) as BugCount from Bugs
group by [Status]
order by BugCount desc,[Status];

select Severity,count(*) as BugCount from Bugs
group by Severity
order by BugCount desc,Severity;

select avg(cast(BugCount as decimal(10,2))) as AverageBugsPerProject
from(
select ProjectID,count(*) as BugCount
from Bugs
group by ProjectID
)x;

select sum(case when Priority='Critical' then 1 else 0 end) as CriticalBugs from Bugs;

select max(BugID) as HighestBugID,min(BugID) as LowestBugID from Bugs;

select distinct Severity from Bugs order by Severity;

select top 3 BugID,Title,Priority from Bugs
order by case Priority when 'Critical' then 1 when 'High' then 2 when 'Medium' then 3 when 'Low' then 4 end,BugID;

select p.ProjectName,count(b.BugID) as TotalBugs
from Projects p
left join Bugs b on p.ProjectID=b.ProjectID
group by p.ProjectID,p.ProjectName
having count(b.BugID)>2
order by TotalBugs desc,p.ProjectName;

select b.BugID,p.ProjectName,b.Title,r.Name as ReportedBy,isnull(d.Name,'Not Assigned') as AssignedTo,c.CategoryName,b.Severity,b.Priority,b.[Status]
from Bugs b
inner join Projects p on b.ProjectID=p.ProjectID
inner join Users r on b.ReportedBy=r.UserID
left join Users d on b.AssignedTo=d.UserID
inner join Categories c on b.CategoryID=c.CategoryID
order by b.BugID;

select p.ProjectName,count(b.BugID) as TotalBugs
from Projects p
left join Bugs b on p.ProjectID=b.ProjectID
group by p.ProjectID,p.ProjectName
order by p.ProjectID;

select c.CategoryName,count(b.BugID) as TotalBugs
from Bugs b
right join Categories c on b.CategoryID=c.CategoryID
group by c.CategoryID,c.CategoryName
order by c.CategoryID;

select u1.Name as User1,u2.Name as User2,r.RoleName
from Users u1
inner join Users u2 on u1.RoleID=u2.RoleID and u1.UserID<u2.UserID
inner join Roles r on u1.RoleID=r.RoleID
order by r.RoleName,u1.UserID,u2.UserID;

select p.ProjectName,pm.UserID
from Projects p
full outer join ProjectMembers pm on p.ProjectID=pm.ProjectID
order by p.ProjectName,pm.UserID;

select BugID,Title,Priority
from Bugs
where Priority=(
select top 1 Priority
from Bugs
order by case Priority when 'Critical' then 1 when 'High' then 2 when 'Medium' then 3 when 'Low' then 4 end
)
order by BugID;

select UserID,Name from Users
where UserID in(
select distinct AssignedTo
from Bugs
where AssignedTo is not null
)
order by UserID;

select p.ProjectID,p.ProjectName from Projects p
where not exists(
select 1
from Bugs b
where b.ProjectID=p.ProjectID
);

select u.UserID,u.Name from Users u
where exists(
select 1
from Bugs b
where b.ReportedBy=u.UserID
)
order by u.UserID;

select ProjectID,ProjectName,BugCount
from(
select p.ProjectID,p.ProjectName,count(b.BugID) as BugCount
from Projects p
left join Bugs b on p.ProjectID=b.ProjectID
group by p.ProjectID,p.ProjectName
)s
where BugCount>(
select avg(cast(BugCount as decimal(10,2)))
from(
select p2.ProjectID,count(b2.BugID) as BugCount
from Projects p2
left join Bugs b2 on p2.ProjectID=b2.ProjectID
group by p2.ProjectID
)a
)
order by ProjectID;

select BugID,Title,Priority from Bugs
where Priority=any(
select Priority from Bugs
where AssignedTo in(4,6,7,9,11)
)
order by BugID;

select BugID,Title from Bugs
where BugID>all(
select BugID from Bugs
where ProjectID=1
);

exec sys.sp_set_session_context @key=N'UserID',@value=4;

begin try
begin transaction;

update Bugs
set [Status]='In Progress'
where BugID=1001 and AssignedTo=4 and [Status]='Assigned';

if @@rowcount=0
throw 50015,'Bug could not be moved to In Progress.',1;

commit transaction;
end try

begin catch
if @@trancount>0
rollback transaction;
throw;
end catch;

begin transaction;

update Bugs
set Priority='Medium'
where BugID=1003;

save transaction BeforeSeverityChange;

update Bugs
set Severity='Critical'
where BugID=1003;

rollback transaction BeforeSeverityChange;

select BugID,Title,Priority,Severity from Bugs
where BugID=1003;

rollback transaction;

begin transaction;

update Bugs
set Priority='Low'
where BugID=1003;

select BugID,Title,Priority
from Bugs
where BugID=1003;

rollback transaction;

exec sys.sp_set_session_context @key=N'UserID',@value=4;

update Bugs
set [Status]='Resolved',ResolvedDate=getdate()
where BugID=1001 and AssignedTo=4 and [Status]='In Progress';

exec sys.sp_set_session_context @key=N'UserID',@value=3;

update Bugs
set [Status]='Closed'
where BugID=1001 and [Status]='Resolved';

exec sys.sp_set_session_context @key=N'UserID',@value=null;

select h.HistoryID,h.BugID,h.OldStatus,h.NewStatus,u.Name as ChangedBy
from BugStatusHistory h
inner join Users u on h.ChangedBy=u.UserID
order by h.HistoryID;

select b.BugID,b.Title,b.[Status],b.Priority,b.Severity,r.Name as Reporter,isnull(d.Name,'Not Assigned') as Developer
from Bugs b
inner join Users r on b.ReportedBy=r.UserID
left join Users d on b.AssignedTo=d.UserID
order by b.BugID;

select u.Name as Developer,count(b.BugID) as AssignedBugs
from Users u
inner join Roles r on u.RoleID=r.RoleID
left join Bugs b on u.UserID=b.AssignedTo
where r.RoleName='Developer'
group by u.UserID,u.Name
order by AssignedBugs desc,u.Name;

select p.ProjectName,b.Severity,count(*) as TotalBugs
from Projects p
inner join Bugs b on p.ProjectID=b.ProjectID
group by p.ProjectID,p.ProjectName,b.Severity
order by p.ProjectID,TotalBugs desc,b.Severity;

select BugID,Title,Severity,Priority,[Status]
from Bugs
where [Status] in('Open','Reopened')
order by case Priority when 'Critical' then 1 when 'High' then 2 when 'Medium' then 3 when 'Low' then 4 end,BugID;

select BugID,Title,Severity,Priority,[Status]
from Bugs
where AssignedTo is null
order by BugID;

select b.BugID,b.Title,p.ProjectName,b.[Status]
from Bugs b
inner join Projects p on b.ProjectID=p.ProjectID
where b.[Status]='Closed'
order by b.BugID;

declare @CreatedBugID int;

exec sys.sp_set_session_context @key=N'UserID',@value=3;

exec spAddBug
 1,
 3,
 3,
 'Database connection timeout',
 'Database requests time out during peak load.',
 'High',
 'High',
 @CreatedBugID output;

select @CreatedBugID as NewlyCreatedBugID;

exec sys.sp_set_session_context @key=N'UserID',@value=2;
exec spAssignBug @CreatedBugID,4;
exec sys.sp_set_session_context @key=N'UserID',@value=null;

declare @TotalProjectBugs int;
exec spGetProjectBugCount 1,@TotalProjectBugs output;
select @TotalProjectBugs as Project1BugCount;

insert into BugComments(BugID,UserID,CommentText)
values(1001,3,'Temporary CRUD test comment');

select CommentID,BugID,UserID,CommentText
from BugComments
where CommentText='Temporary CRUD test comment';

update BugComments
set CommentText='Temporary CRUD test comment updated'
where CommentText='Temporary CRUD test comment';

select CommentID,BugID,UserID,CommentText
from BugComments
where CommentText='Temporary CRUD test comment updated';

delete from BugComments
where CommentText='Temporary CRUD test comment updated';

select CommentID,BugID,UserID,CommentText
from BugComments
where CommentText='Temporary CRUD test comment updated';
