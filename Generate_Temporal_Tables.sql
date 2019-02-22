-- This Script generates Temporal tables to every table inside a database, except the ones, that has no primary key defined.
-- Use it wisely

DECLARE @tablename nvarchar(200);
DECLARE @scriptadd nvarchar(max);
DECLARE @scriptextension nvarchar(max);

-- ---------------------------------------------------------------------
-- Create helper tables
-- ---------------------------------------------------------------------
CREATE TABLE XTemporalTableGenerationLog
(
	Log nvarchar(500),
	Date datetime
)

CREATE TABLE XTemporalTableAdd
(
	TableName nvarchar(200),
	ScriptAdd nvarchar(max),
	ScriptExtension nvarchar(max),
	IsFinished int
)

-- ---------------------------------------------------------------------
-- Generate the necessary scripts into a helper table
-- ---------------------------------------------------------------------
-- Note: You can leave out the last LEFT JOIN and WHERE clause, if you want to generate Temporal tables to the tables that has no primary keys too.
-- ---------------------------------------------------------------------
INSERT INTO XTemporalTableAdd (TableName, ScriptAdd, ScriptExtension, IsFinished)
SELECT		
	t.name,
	'ALTER TABLE ' + t.name
	+ ' ADD SysStartTime datetime2(0) GENERATED ALWAYS AS ROW START HIDDEN '
	+ 'CONSTRAINT ' + t.name + '_SysStart DEFAULT CONVERT(datetime2 (0), ''2018-01-01 00:00:01''),'
	+ ' SysEndTime datetime2(0) GENERATED ALWAYS AS ROW END HIDDEN '
	+ 'CONSTRAINT ' + t.name + '_SysEnd DEFAULT CONVERT(datetime2 (0), ''9999-12-31 23:59:59''), '
	+ 'PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime); ',
	'ALTER TABLE ' + t.name
	+ ' SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [dbo].TH_' + t.name + '))',
	0
FROM sys.tables t
LEFT JOIN 
(
	SELECT name
	FROM sys.tables
	WHERE OBJECTPROPERTY(OBJECT_ID,'TableHasPrimaryKey') = 0
) as t2 ON t.name = t2.name
WHERE t2.name IS NULL

-- ---------------------------------------------------------------------
-- Execute the previously generated scripts.
-- ---------------------------------------------------------------------
DECLARE forcursor CURSOR FOR SELECT TableName, ScriptAdd, ScriptExtension FROM XTemporalTableAdd
OPEN forcursor  
FETCH NEXT FROM forcursor   
INTO @tablename, @scriptadd, @scriptextension

WHILE @@FETCH_STATUS = 0  
BEGIN  

	exec sp_executesql @scriptadd
	exec sp_executesql @scriptextension

	UPDATE XTemporalTableAdd SET IsFinished = 1 
	WHERE TableName = @tablename
	
	INSERT INTO XTemporalTableGenerationLog
	VALUES('Temporal Table Generated for ' + @tablename ,GETDATE());
	
    FETCH NEXT FROM forcursor   
    INTO @tablename, @scriptadd, @scriptextension
END   
CLOSE forcursor;  
DEALLOCATE forcursor; 

-- ---------------------------------------------------------------------
-- Drop helper tables
-- ---------------------------------------------------------------------
DROP TABLE XTemporalTableGenerationLog;
DROP TABLE XTemporalTableAdd;