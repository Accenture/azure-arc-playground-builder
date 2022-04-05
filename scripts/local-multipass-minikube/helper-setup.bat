@echo off

rem check for multipass - https://multipass.run/
where multipass
if %ERRORLEVEL% NEQ 0 ECHO MULTIPASS DOESN'T EXIST! && pause

set currentuser=%username%
set currentuser=%currentuser:.=%
set currentuser=%currentuser:-=%

set randomnumber=%random%

set localclustername=minikube-%currentuser%-%randomnumber%

set arcclustername=arc-%localclustername%

@echo on