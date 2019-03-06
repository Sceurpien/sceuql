-- This Script Lists all the possible foreign key violations in your database, including the ones that has "NULL" values.
-- The NULL Value columns are not neccessary causing problems, however it can be a problem.
-- If you only want the Non-NULL foreign key violations, see the last aprt of the script.
-- Use it wisely
SET NOCOUNT ON

-- ---------------------------------------------------------------------
-- Create helper table
-- ---------------------------------------------------------------------
CREATE TABLE XListOf_ForeignKeys
(
	ForeignKeyName nvarchar(500),
	ReferencingTableName nvarchar(100),
	ReferencingColumnName nvarchar(100),
	ReferencedTableName nvarchar(100),
	ReferencedColumnName nvarchar(100),
	NumberOfIssuesWithoutNull int,
	NumberOfNullIssues int,
	SelectTheList  nvarchar(max),
)

-- ---------------------------------------------------------------------
-- Get the neccessary helper informations
-- ---------------------------------------------------------------------
INSERT INTO XListOf_ForeignKeys
SELECT
    f.name constraint_name
   ,OBJECT_NAME(f.parent_object_id) referencing_table_name
   ,COL_NAME(fc.parent_object_id, fc.parent_column_id) referencing_column_name
   ,OBJECT_NAME (f.referenced_object_id) referenced_table_name
   ,COL_NAME(fc.referenced_object_id, fc.referenced_column_id) referenced_column_name
   ,0
   ,0
   ,''
FROM sys.foreign_keys AS f
INNER JOIN sys.foreign_key_columns AS fc
   ON f.object_id = fc.constraint_object_id
INNER JOIN sys.columns AS c ON fc.referenced_object_id = c.OBJECT_ID AND fc.referenced_column_id = c.column_id


-- ---------------------------------------------------------------------
-- Inspecting foreign keys
-- ---------------------------------------------------------------------
DECLARE @ForeignKeyName nvarchar(500);
DECLARE @ReferencingTableName nvarchar(500);
DECLARE @ReferencingColumnName nvarchar(500);
DECLARE @ReferencedTableName nvarchar(500);
DECLARE @ReferencedColumnName nvarchar(500);
DECLARE @Script nvarchar(max);

DECLARE forcursor CURSOR FOR 
SELECT ForeignKeyName, ReferencingTableName, ReferencingColumnName, ReferencedTableName, ReferencedColumnName
FROM XListOf_ForeignKeys
OPEN forcursor  
FETCH NEXT FROM forcursor   
INTO @ForeignKeyName, @ReferencingTableName, @ReferencingColumnName, @ReferencedTableName, @ReferencedColumnName

WHILE @@FETCH_STATUS = 0  
BEGIN  

	PRINT 'Checking Foreign Key ' + @ForeignKeyName;

	SET @Script = '
		UPDATE XListOf_ForeignKeys 
		SET 
			NumberOfIssuesWithoutNull = 
				(
					SELECT COUNT(1) FROM ' + @ReferencingTableName + ' sub
					WHERE NOT EXISTS 
								(
									SELECT 1 FROM ' + @ReferencedTableName + ' parent 
									WHERE parent.' + @ReferencedColumnName + ' = sub.' + @ReferencingColumnName + '
								) AND sub.' + @ReferencingColumnName + ' IS NOT NULL
				),
			NumberOfNullIssues = 
				(
					SELECT COUNT(1) FROM ' + @ReferencingTableName + ' sub
					WHERE sub.' + @ReferencingColumnName + ' IS NULL
				),
			SelectTheList =
				'' SELECT * FROM ' + @ReferencingTableName + ' sub WHERE NOT EXISTS 
					(
						SELECT 1 FROM ' + @ReferencedTableName + ' parent 
						WHERE parent.' + @ReferencedColumnName + ' = sub.' + @ReferencingColumnName + '
					)
				''
		WHERE ForeignKeyName = ''' + @ForeignKeyName + ''' AND ReferencingColumnName = ''' + @ReferencingColumnName +''' '
	exec sp_executesql @Script
	
    FETCH NEXT FROM forcursor   
    INTO @ForeignKeyName, @ReferencingTableName, @ReferencingColumnName, @ReferencedTableName, @ReferencedColumnName
END   
CLOSE forcursor;  
DEALLOCATE forcursor; 

-- ---------------------------------------------------------------------
-- List issues
-- If you want to only list Non-NULL values, comment/delete the fist line, and uncomment the second line
-- ---------------------------------------------------------------------
SELECT * FROM XListOf_ForeignKeys WHERE (NumberOfIssuesWithoutNull > 0) OR (NumberOfNullIssues > 0)
--SELECT * FROM XListOf_ForeignKeys WHERE (NumberOfIssuesWithoutNull > 0)
ORDER BY ReferencedTableName, ForeignKeyName, ReferencedColumnName

-- ---------------------------------------------------------------------
-- Drop helper table
-- ---------------------------------------------------------------------
DROP TABLE XListOf_ForeignKeys