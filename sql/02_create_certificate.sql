-- STEP 3a | Run on: sql1
-- On Windows, AG endpoints usually authenticate with Windows/AD accounts. In Linux containers
-- there is no domain, so the endpoints authenticate with a CERTIFICATE instead.
-- We create one certificate here and copy it (with its private key) to the other replicas.
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbm_certificate')
    CREATE CERTIFICATE dbm_certificate
        AUTHORIZATION dbm_user
        WITH SUBJECT = 'AG endpoint authentication',
             EXPIRY_DATE = '20351231';

PRINT CONCAT(@@SERVERNAME, ': dbm_certificate created');

-- scripts/setup.sh then exports it as hex, no .cer/.pvk files need to be copied around:
--   SELECT CONVERT(varchar(max), CERTENCODED(CERT_ID('dbm_certificate')), 1);
--   SELECT CONVERT(varchar(max), CERTPRIVATEKEY(CERT_ID('dbm_certificate'), '<CERT_PASSWORD>'), 1);
