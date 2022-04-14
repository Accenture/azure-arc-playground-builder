set "joinCommand="
for /f "skip=1 delims=" %%a in (
 'multipass exec %localclustername%-1 -- bash -c "microk8s add-node"'
) do if not defined sid set "joinCommand=%%a"