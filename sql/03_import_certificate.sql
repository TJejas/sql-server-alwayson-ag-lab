-- STEP 3b | Run on: sql2, sql3
-- Recreates sql1's certificate from the hex exported by CERTENCODED / CERTPRIVATEKEY.
-- The private key travels encrypted with CERT_PASSWORD and is re-protected by this
-- server's own master key on import.
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbm_certificate')
    CREATE CERTIFICATE dbm_certificate
        AUTHORIZATION dbm_user
        FROM BINARY = $(CERT_HEX)
        WITH PRIVATE KEY (
            BINARY = $(KEY_HEX),
            DECRYPTION BY PASSWORD = '$(CERT_PASSWORD)'
        );

SELECT @@SERVERNAME AS server_name, name, subject, expiry_date,
       CONVERT(varchar(42), thumbprint, 1) AS thumbprint
FROM sys.certificates WHERE name = 'dbm_certificate';
