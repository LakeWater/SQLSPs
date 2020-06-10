/*-----------------------------------------------------------------------------------------------------
Procedure   :	[Trim_Leading_Zeroes]
Created By  :	Samantha Budd
Created Date:	06/28/2018
Remarks     :	Intended to bulk insert data from multiple TXT files with numerous columns and
				remove leading zeroes (2-4) from the [Identifier] column.
---------------------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[Trim_Leading_Zeroes]
AS BEGIN

DECLARE @CMD VARCHAR(8000)
DECLARE @CMD1 VARCHAR(8000) 
DECLARE @CMD2 VARCHAR(8000)
DECLARE @FilePath VARCHAR(1000)
DECLARE @FileOriginalPath VARCHAR(1000) = '\\some\path\here\'
DECLARE @fileName VARCHAR(100)
DECLARE @Msg VARCHAR(MAX)
DECLARE @Counter INT
DECLARE @bulkInsert VARCHAR(MAX) 
DECLARE @x INT 

IF OBJECT_ID('tempdb..#FileList') IS NOT NULL 
		DROP TABLE #FileList
IF OBJECT_ID('tempdb..#test_cmdshell') IS NOT NULL 
		DROP TABLE #test_cmdshell	
--optional test table for bulk inserting data		
--IF OBJECT_ID('tempdb..##testZeroData') IS NOT NULL 
--		DROP TABLE ##testZeroData

CREATE TABLE #FileList (Col1 VARCHAR(1000) NULL)
CREATE TABLE #test_cmdshell (Info VARCHAR(255) NULL)
--CREATE TABLE ##testZeroData (Col1 VARCHAR(250) NULL, Col2 VARCHAR(250) NULL, Col3 VARCHAR(250) NULL, Col4 VARCHAR(250) NULL)

/*-------------------------------------------------------------------------------------
				GET LIST OF FILES FROM THE FILEORIGINAL PATH
-------------------------------------------------------------------------------------*/

	BEGIN TRY
		-- 2 - Build the string to capture the file names in the restore location
		SELECT @CMD1 = CONCAT('master.dbo.xp_cmdshell ', char(39), 'dir ', @FileOriginalPath, '*' ,' /A-D  /B' , char(39))

		-- 3 - Build the string to populate the #FileList temporary table
		SELECT @CMD2 = CONCAT('INSERT INTO #\FileList(Col1)' , char(13) ,
		'EXEC ' , @CMD1)

		BEGIN TRY
			-- 4 - Execute the string to populate the #FileList table
			EXEC (@CMD2)
		END TRY

		BEGIN CATCH
			SET @Msg = CONCAT(@@ERROR , ' - ' , ERROR_MESSAGE() )
			PRINT @Msg
		END CATCH
		
		-- Delete trash results
		DELETE FROM #FileList
		WHERE Col1 IS NULL OR Col1 LIKE '%Volume%' OR Col1 LIKE '%Directory%' OR COL1 LIKE '%<DIR>%' OR COL1 LIKE '%bytes%' 		
	END TRY

	BEGIN CATCH
		SET @Msg = CONCAT(@Msg , @@ERROR , '-' , ERROR_MESSAGE() )
		PRINT @Msg
	END CATCH

	--uncomment to verify files imported correctly
	--select * from #FileList


/*-------------------------------------------------------------------------------------
				BULK INSERT DATA FROM FILES IN FILE LIST
-------------------------------------------------------------------------------------*/


SET @Counter = (select count(*) from #FileList)
SET @x = 1 

WHILE @x <= @counter 
	BEGIN

		--select text files from the FileList temp table
		IF EXISTS (SELECT TOP 1 1 FROM #FileList /*where Col1 like '%txt%'*/)
	
		BEGIN TRY
			set @fileName = (select top 1 * from #FileList)
				IF @fileName like '%Intended_File_Name_Here%'
				BEGIN
					TRUNCATE TABLE [dbo].[Table_where_you_want_data]
					--SET @FileCompletePath = CONCAT(@FileOriginalPath , @fileName)
					--ROWTERMINATOR updated from \n to 0x0a to account for hex encoding of text files
					set @bulkInsert = CONCAT('BULK INSERT [dbo].[Table_where_you_want_data] FROM ''' , @FileOriginalPath , @fileName , ''' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'')')
					EXEC (@bulkInsert)

					Update [dbo].[Table_where_you_want_data]
					Set [HEADER2] = REPLACE(HEADER2, CHAR(34), '')

					IF @@SERVERNAME LIKE '%Your_DEV_Test_Server%' 
					BEGIN
						SELECT @FilePath = concat('\\some\path\here\', @fileName, 'Intended_File_Name_Here' ,CONVERT(VARCHAR,GETDATE(),112)/*, '.txt'*/)
						--select columns of data being imported
							
						SELECT @CMD = '"SET NOCOUNT ON; SELECT [Accountnumber] + Char(44) + [Identifier] + Char(44) + [Type] + Char(44) + [Code] + Char(44) + [Date] + Char(44) + '
						SELECT @CMD = CONCAT(@CMD, '[CateogryCode] + Char(44) + [CategoryName] + Char(44) + [SubCategoryCode] + Char(44) + [SubCategoryName] + Char(44) + [Narrative] FROM dbo.Table_where_you_want_data')
						
						SELECT @CMD = CONCAT(@CMD, ' UNION SELECT [Accountnumber] + Char(44) + SUBSTRING([Identifier],2,LEN([Identifier])) + Char(44) + [Type] + Char(44) + [Code] + Char(44) + [Date] + Char(44) + ')
						SELECT @CMD = CONCAT(@CMD, '[CateogryCode] + Char(44) + [CategoryName] + Char(44) + [SubCategoryCode] + Char(44) + [SubCategoryName] + Char(44) + [Narrative] FROM dbo.Table_where_you_want_data WHERE LEN([Identifier]) = 10 and LEFT([Identifier],1)=''0''')
										
						SELECT @CMD = CONCAT(@CMD, ' UNION SELECT [Accountnumber] + Char(44) + SUBSTRING([Identifier],4,LEN([Identifier])) + Char(44) + [Type] + Char(44) + [Date] + Char(44) + ')
						SELECT @CMD = CONCAT(@CMD, '[CateogryCode] + Char(44) + [CategoryName] + Char(44) + [SubCategoryCode] + Char(44) + [SubCategoryName] + Char(44) + [Narrative] FROM dbo.Table_where_you_want_data WHERE LEN([Identifier]) = 10 and LEFT([Identifier],2)=''00''"')
											
						SET @CMD = CONCAT('sqlcmd -E -d Test -h-1 -W -S ' , CAST(@@SERVERNAME AS VARCHAR(100)) , ' -q '  , @CMD , ' -o "' , @FilePath , '"')

						INSERT INTO #test_cmdshell(Info) --define #cmdshell temp table to hold results before the loop
						EXEC MASTER.dbo.xp_cmdshell @CMD
					END
				END
		END TRY
		BEGIN CATCH
			SET @Msg = CONCAT(@@ERROR , ' - ' , ERROR_MESSAGE() )
			PRINT @Msg
		END CATCH
		
		--select * from [dbo].[Table_where_you_want_data]
		--select * from #test_cmdshell
		
	DELETE FROM #FileList where Col1 = @fileName
	SET @x=@x+1
	END
END
