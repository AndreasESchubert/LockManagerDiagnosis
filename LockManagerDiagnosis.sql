-- Check: is Lock Manager using an overly high proportion of the available memory?
-- This will return at list of findings per instance. Everything that has 'Review=1' should be addressed, the others are informational

DECLARE @OSMemoryMB bigint,
	@MemoryUsedBySQLMB bigint,
	@LockManagerUsingMB bigint,
	@msg nvarchar(max)

-- physical memory available
	SELECT @OSMemoryMB = (total_physical_memory_kb/1024) 
	FROM sys.dm_os_sys_memory;
-- how much is SQL currently using
	SELECT @MemoryUsedBySQLMB = (physical_memory_in_use_kb/1024)
	FROM sys.dm_os_process_memory;

-- how much is reserved by lock manager across all nodes?
	SELECT @LockManagerUsingMB = SUM((pages_kb / 1024))
	FROM sys.dm_os_memory_clerks
	GROUP by type
	HAVING type = N'OBJECTSTORE_LOCK_MANAGER'

DECLARE @Findings TABLE(Finding nvarchar(max), Description nvarchar(max), Review int)

-- is the buffer pool the  top consumer?
if (SELECT TOP 1 type FROM sys.dm_os_memory_clerks ORDER BY pages_kb DESC) <> 'MEMORYCLERK_SQLBUFFERPOOL'
	INSERT INTO @Findings 
	SELECT N'Buffer pool is not your top memory consumer. This is unusal',N'The buffer pools should be your #1 memory consumer, otherwise you are hitting the disk more than necessary',1

-- what percentage of the available memory is lock manager currently using?	
SET @msg =  'Currently at ' + cast(@LockManagerUsingMB as nvarchar(max)) + ' MB ('  + cast((@LockManagerUsingMB * 100 / @MemoryUsedBySQLMB) as nvarchar(max)) + '%)'
if (@LockManagerUsingMB * 100 / @MemoryUsedBySQLMB)>50
	INSERT INTO @Findings 
	SELECT N'Lock Manager using more than 50% of the total SQL memory.' + @msg, N'A percentage > 50% points to excessive locking. Review escalation settings and queries holding too many locks', 1
ELSE IF (@LockManagerUsingMB * 100 / @MemoryUsedBySQLMB)>10
	INSERT INTO @Findings 
	SELECT N'Lock Manager using more than 10% of the total SQL memory.' + @msg, N'A percentage > 10% points to severe locking. Review escalation settings and queries holding too many locks', 1
ELSE
	INSERT INTO @Findings 
	SELECT N'Lock Manager  using less than 10% of the total SQL memory.' + @msg, N'A percentage < 10% points to normal locking. Review escalation settings and queries holding too many locks', 0


-- version check borrowed from BrentOzar
	IF OBJECT_ID ('tempdb..#checkversion') IS NOT NULL
			DROP TABLE #checkversion;
		CREATE TABLE #checkversion (
			version NVARCHAR(128),
			common_version AS SUBSTRING(version, 1, CHARINDEX('.', version) + 1 ),
			major AS PARSENAME(CONVERT(VARCHAR(32), version), 4),
			minor AS PARSENAME(CONVERT(VARCHAR(32), version), 3),
			build AS PARSENAME(CONVERT(VARCHAR(32), version), 2),
			revision AS PARSENAME(CONVERT(VARCHAR(32), version), 1)
		);

	INSERT INTO #checkversion (version)
		SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128))
		OPTION (RECOMPILE);

	DECLARE	@v DECIMAL(6,2),
	@build INT
		
	SELECT @v = common_version ,
				@build = build
		FROM   #checkversion
		OPTION (RECOMPILE);

-- is the new behaviour available on this machine?
IF (@v < 17) 
	INSERT INTO @Findings 
	SELECT N'Dxnamic max lock manager cache memory configuration not available on your SQL. Monitor the usage manually', N'SQL 2025 CU5 introduced a new setting to control this. Refer to https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/max-lock-manager-cache-memory-configuration-option?view=sql-server-ver17 for more details',0

if (@v=17 AND @build < 4045)
	INSERT INTO @Findings 
	SELECT N'Dxnamic max lock manager cache memory configuration not available before CU 5. Consider updating' , N'SQL 2025 CU5 introduced a new setting to control this. Refer to https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/max-lock-manager-cache-memory-configuration-option?view=sql-server-ver17 for more details',0

if (@v=17 AND @build >= 4045)
	INSERT INTO @Findings 
	SELECT N'Dxnamic max lock manager cache memory configuration available on your SQL' , N'SQL 2025 CU5 introduced a new setting to control this. Refer to https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/max-lock-manager-cache-memory-configuration-option?view=sql-server-ver17 for more details',0


SELECT * from @Findings
