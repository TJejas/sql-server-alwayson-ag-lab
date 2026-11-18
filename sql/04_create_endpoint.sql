-- STEP 4 | Run on: ALL replicas
-- The database mirroring endpoint is the TCP listener (port 5022) replicas use to ship
-- transaction log blocks to each other. It is separate from the client port 1433.
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.database_mirroring_endpoints WHERE name = 'Hadr_endpoint')
    CREATE ENDPOINT [Hadr_endpoint]
        AS TCP (LISTENER_PORT = 5022)
        FOR DATABASE_MIRRORING (
            ROLE = ALL,                                   -- can act as primary or secondary
            AUTHENTICATION = CERTIFICATE dbm_certificate, -- trust = same certificate
            ENCRYPTION = REQUIRED ALGORITHM AES           -- log traffic encrypted on the wire
        );

ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED;
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [dbm_login];

SELECT @@SERVERNAME AS server_name, e.name, e.state_desc, e.role_desc,
       e.connection_auth_desc, e.encryption_algorithm_desc, t.port
FROM sys.database_mirroring_endpoints e
JOIN sys.tcp_endpoints t ON t.endpoint_id = e.endpoint_id;
