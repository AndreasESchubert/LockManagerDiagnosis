# LockManagerDiagnosis

SQL Server Lock Manager can use up to 60% of the total available memory due to excessive locking.
This may - in rare occasions lead to unresponsive SQL Servers, even if you have a large amount of total memory.
What's more important though is that SQL Server never releases that memory again, even when the offending queries have long been gone.

Following an initial description of the problem and how I diagnosed it (see https://www.linkedin.com/posts/schubertandreas_sql-server-surprised-me-even-after-25-years-activity-7464986776877547521-gHxp?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAHzDEEBJbu7vhhVPlhF6Kbrqebi98MvHZw ), I raised a bug request with Microsoft (see https://feedback.azure.com/d365community//idea/0c7f7389-f558-f111-89e7-7c1e52d83a79 )
Microsoft confirmed this behaviour for all SQL Servers up to SQL 2025 (CU5).
In CU5, a new setting has been introduced to change that behaviour (https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/max-lock-manager-cache-memory-configuration-option?view=sql-server-ver17)

Since I am managing a large amount of SQL Servers day by day, I decided to spin up a quick diagnosis tool to check for this.

This is an early draft of the script. Feel free to use it as necessary.
