@REM
@REM Author: DeHartB (dehartb@battelle.org)
@REM
@REM

@ECHO OFF

SET BASE_DIR="%cd%"
SET CURRENT_USER=%USERDOMAIN%\%USERNAME%
SET BUILTIN_USERS=BUILTIN\Users
SET LOGFILE=%BASE_DIR%\SecureTomDB-Exec.log
SET INFOFILE=%BASE_DIR%\TomcatInfo.properties
SET JAVA_ENC_FILE=EncDecJDBCPass.java
SET TEMP_JAVA_ENC_FILE=EncDecJDBCPass_temp.java
SET BAK_JAVA_ENC_FILE=EncryptJDBCPassword-Original.java
SET CLASS_ENC_FILE=EncDecJDBCPass.class
SET JAVA_DS_FILE=SecureTomcatDataSourceImpl.java
SET CLASS_DS_FILE=SecureTomcatDataSourceImpl.class
SET JAVA_STJ_FILE=SecureTomcatJDBC.jar
SET LOG_STJ_FILE=SecureTomcatJDBC.log
SET CMD_ENV_FILE=SetEnv.bat
SET SECRET_PHRASE_REPLACE=PHRASETOREPLACE
SET EMPTYSTRING=

@REM Ensure we are always working with a fresh password
SET passwordtoencrypt=


@REM DELETE TEMP FILES
DEL /f /q %INFOFILE%
DEL /f /q %BASE_DIR%\*.class

@REM RUN SETENVBAT FILE FOR ANY PRECONFIGURED VALUES
IF EXIST "%CMD_ENV_FILE%" (
	ECHO ADDING PRESET ENVIRONMENT VARIABLES
	CALL %CMD_ENV_FILE% %*
)

@REM CHECK FOR PRECONFIGURED CATALINA_HOME, ELSE TAKE INPUT
@REM HANDLE Quotes in CATALINA_HOME
IF "%CATALINA_HOME%"=="" (
	SET /p InstanceDir="Enter the Tomcat Instance CATALINA_HOME ( A Parent Directory of conf/ bin/ webapps/): "
	SET CATALINA_HOME=%InstanceDir%
	@REM remove quotes if exist
) ELSE (
	ECHO CATALINA_HOME IS SET TO %CATALINA_HOME%
	SET InstanceDir=%CATALINA_HOME%
)

SETLOCAL EnableDelayedExpansion
IF EXIST "%InstanceDir%" (
	
	IF EXIST "%InstanceDir%"\bin\version.bat (
		ECHO STARTING VERSION CHECK
		SET permission=false
		
		FOR /F "delims=" %%F IN ('ICACLS "%InstanceDir%"\bin\version.bat ^| FINDSTR  /ic:"%CURRENT_USER%" /ic:"%BUILTIN_USERS%"') DO (
	
			SET str1=%%F
			SET str2=!str1:(F^)=!
			SET str3=!str1:(RX^)=!
			
			IF NOT x!str3!==x!str1! ( 
				ECHO User or builtin user has full permissions
				SET permission=true
	
			)
			IF NOT x!str2!==x!str1! (  
				ECHO User or builtin user has execute permissions
				SET permission=true
				
			)
		)
		
		ECHO permission set to !permission!
		IF !permission!==true (
			CALL "%InstanceDir%"\bin\version.bat > %INFOFILE%
		) ELSE (
			ECHO ERROR: Execute Permission is not set
			EXIT 9
		)
	) ELSE (
		ECHO ERROR: Unable to find the version.bat under %InstanceDir%\bin 
		EXIT 9
	)
)
ENDLOCAL
ECHO Completed version.bat task

CD %BASE_DIR%

IF EXIST %INFOFILE% (

	FOR %%A IN (%INFOFILE%) DO IF NOT %%~zA==0 (
		FINDSTR /ic:"Server Version" %INFOFILE%
		FINDSTR /ic:"JVM Version" %INFOFILE%
		FINDSTR /ic:"JAVA" /ic:"JRE" %INFOFILE% 
		FINDSTR /ic:"CATALINA_HOME" %INFOFILE%
		FINDSTR /ic:"CLASSPATH" %INFOFILE%
	)
)

@REM IF JAVA_HOME IS NOT DEFINED USE TOMCAT DEFINED JAVA_HOME
IF "%JAVA_HOME%" == "" (
	FOR /F "delims=" %%a IN ('FINDSTR /ic:"JAVA" /ic:"JRE" %INFOFILE% ') DO SET JAVA_HOME_TC=%%a
	
	SETLOCAL ENABLEDELAYEDEXPANSION
	SET search=USING JRE_HOME:
	CALL SET JAVA_HOME_TC=%%JAVA_HOME_TC:%search%=%EMPTYSTRING%%%
	SET search=USING JAVA_HOME:
	CALL SET JAVA_HOME_TC=%%JAVA_HOME_TC:%search%=%EMPTYSTRING%%%
	FOR /f "tokens=* delims= " %%a IN ("%JAVA_HOME_TC%") DO SET JAVA_HOME_TC=%%a
	SET JAVA_HOME=%JAVA_HOME_TC%
)

SET JAVA_HOME_VALID=1

IF EXIST %JAVA_HOME%\bin\javac.exe (
	IF EXIST %JAVA_HOME%\bin\java.exe (
		IF EXIST %JAVA_HOME%\bin\jar.exe (
			ECHO INFO: Java Home Validation Successful. Good to Go
		) ELSE (
			SET JAVA_HOME_VALID=0
		)
	) ELSE (
		SET JAVA_HOME_VALID=0
	)
) ELSE (
	SET JAVA_HOME_VALID=0
)

IF %JAVA_HOME_VALID% equ 0 (
	SET JAVA_HOME_VALID=0
	ECHO ERROR: Java Home Does not seem to be having either JAVAC or JAVA or JAR command.
	ECHO Trying to Obtain JAVA_HOME during runtime
	ECHO Enter the JAVA_HOME:
	SET /p JAVA_HOME_IN=
	IF EXIST %JAVA_HOME%\bin\javac.exe (
		IF EXIST %JAVA_HOME%\bin\java.exe (
			IF EXIST %JAVA_HOME%\bin\jar.exe (
				ECHO INFO: Java Home Validation Successful - RUNTIME. Good to Go
			) ELSE (
				SET JAVA_HOME_VALID=0
			)
		) ELSE (
			SET JAVA_HOME_VALID=0
		)
	) ELSE (
		SET JAVA_HOME_VALID=0
	)
	
	IF %JAVA_HOME_VALID% equ 0 (
		ECHO I am Sorry the Given JAVA_HOME does not seem to having JAVAC or JAVA or JAR command either
		ECHO If you feel there is a BUG. Please write email to my author dehartb@battelle
	)
)


SET JULI_JAR_LOC="%InstanceDir%"\bin\tomcat-juli.jar
SET JDBC_JAR_LOC="%InstanceDir%"\lib\tomcat-jdbc.jar

ECHO INFO: Vaidating the Tomcat Juli and Tomcat JDBC Jar files availability

IF EXIST %JULI_JAR_LOC% (
	IF EXIST %JDBC_JAR_LOC% (
		ECHO INFO: Jar files are present. Good to Go
	) ELSE (
		ECHO ERROR: Unable to find the Jar file %JDBC_JAR_LOC%
		EXIT 10
	)
) ELSE (
	ECHO ERROR: Unable to find the Jar file %JDBC_JAR_LOC%
	EXIT 10
)

IF "%passwordtoencrypt%" == "" (
	ECHO Enter the Password to Encrypt
	SET /p passwordtoencrypt=
) ELSE (
	ECHO password to encrypt: %passwordtoencrypt%	
)

IF "%secretphrase%" == "" (
	ECHO Enter the Secret PassPhrase
	SET /p secretphrase=
) ELSE (
	ECHO secret passphrase: %secretphrase%	
)

xcopy %JAVA_ENC_FILE% %BASE_DIR%\%BAK_JAVA_ENC_FILE%* /y

IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: failed to take backup of $JAVA_ENC_FILE
)

SET ENTERED_INFO_VALID=1
IF %secretphrase% == "" SET ENTERED_INFO_VALID=0
IF %passwordtoencrypt% == ""  SET ENTERED_INFO_VALID=0

IF %ENTERED_INFO_VALID% == 1 (
	
	(FOR /f "delims=" %%i IN (%JAVA_ENC_FILE%) DO (
    SET "line=%%i"
    SETLOCAL enabledelayedexpansion
    SET "line=!line:%SECRET_PHRASE_REPLACE%=%secretphrase%!"
    ECHO(!line!
    ENDLOCAL
	))>"%TEMP_JAVA_ENC_FILE%
	
	XCOPY %TEMP_JAVA_ENC_FILE% %JAVA_ENC_FILE%* /y
	DEL %TEMP_JAVA_ENC_FILE%
	
) ELSE (
	ECHO ERROR: Either PassPhrase or the Password is Empty
)

ECHO Creating the JAR module and Compiling the code

%JAVA_HOME%\bin\javac -cp "%CATALINA_HOME%"\lib;%JDBC_JAR_LOC%;%JULI_JAR_LOC%;. %JAVA_ENC_FILE% && %JAVA_HOME%\bin\javac -cp "%CATALINA_HOME%"\lib;%JDBC_JAR_LOC%;%JULI_JAR_LOC%;. %JAVA_DS_FILE%

IF %ERRORLEVEL% EQU 0 (
	IF EXIST %CLASS_ENC_FILE% (
		IF EXIST  %CLASS_DS_FILE% (
			ECHO Class files are created. Good to Go
		) ELSE (
			ECHO ERROR: Classfiles are not Created. Please check manually
		)
	) ELSE (
		ECHO ERROR: Classfiles are not Created. Please check manually
	)
) ELSE (
	ECHO Class Compilation Errors Found. Please check manually
	EXIT 11
)

ECHO INFO: Creating a Jar file %JAVA_STJ_FILE%

%JAVA_HOME%\bin\jar cvef EncDecJDBCPass %JAVA_STJ_FILE% *.class

IF %ERRORLEVEL% EQU 0 (
	IF EXIST %JAVA_STJ_FILE% (
		ECHO INFO: Jar file Creation Successful. Good to Go
	) ELSE (
		ECHO ERROR: JAR FILE NOT FOUND
		EXIT 12
	)
) ELSE (
	ECHO ERROR: Jar Creation Failed
	EXIT 12
)


FOR /F "delims=" %%a IN ('%JAVA_HOME%\bin\java -jar %JAVA_STJ_FILE% ^| findstr /i usage %LOG_STJ_FILE%') DO SET USAGE_FOUND=%%a

IF NOT "%USAGE_FOUND%" == "" (
	ECHO "Password Encryption Begins for %passwordtoencrypt%"
	%JAVA_HOME%\bin\java -jar %JAVA_STJ_FILE% %passwordtoencrypt%
	
	FOR /l %%x IN (1, 1, 100) DO (

		SETLOCAL EnableDelayedExpansion
		SET /p response="Encrypt another password y/n: "
				
		IF /I "!response!" EQU "YES" SET validresponse=1
		IF /I "!response!" EQU "Y" SET validresponse=1
		
		IF !validresponse! EQU 1 (
			SET /p passwordresponse="Enter the Password to Encrypt: "
			ECHO "Password Encryption Begins for !passwordresponse!"
			%JAVA_HOME%\bin\java -jar %JAVA_STJ_FILE% !passwordresponse!
		) ELSE (
			@REM FIND ANOTHER WAY TO BREAK FOR LOOP
			ENDLOCAL
			GOTO ENDPASSWORD
		)	
		ENDLOCAL
	)
) ELSE (
	ECHO ERROR: Unable to Encrypt the Password. Sorry. Please report this problem to my Creator at aksarav@middlewareinventory.com
	EXIT 13
)
:ENDPASSWORD

ECHO Password Encryption Completed. Your Encrypted Password is displayed above

XCOPY %BAK_JAVA_ENC_FILE% %JAVA_ENC_FILE%* /y
DEL /f /q %BAK_JAVA_ENC_FILE%
DEL /f /q %BASE_DIR%\*.class

ECHO Next Steps: 
ECHO 1) Copy the Generated SecureTomcatJDBC.jar into the %InstanceDir%\lib directory
ECHO 2) Replace the Factory element in Context.xml with factory="SecureTomcatDataSourceImpl"
ECHO 3) Replace the Encrypted Password in place of Clear Text Password password="ENCRYPTED PASSWORD"
ECHO For Any Questions about this tool read the product page https://www.middlewareinventory.com/blog/secure-tomcat-jdbc/. Leave a Comment there for any help
ECHO Good Bye. Thanks for using SecureTomcatJDBC Application


