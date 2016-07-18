# Chrome OS workflow methods
if [ -e ~/deviceip ]; then
	export DEVICE=$(cat ~/deviceip)
fi
setboard() { export B=--board="$*"; export BOARD="$*"; echo $B; }
setdevice(){ export DEVICE="$*"; echo "$*" > ~/deviceip; }
deploy() { emerge-$BOARD "$*" && cros deploy $DEVICE "$*"; }


# GIT history editing methods
CL_IN_EDIT=NONE
cledit() {
  export CL_IN_EDIT=$(git log --pretty=format:'%h %s' --abbrev-commit | grep "$*" | cut -d " " -f1 | head -n1);
  echo "Editing: $(gitlogall | grep $CL_IN_EDIT)"
  git checkout $CL_IN_EDIT
}
clrebase() { git rebase --onto HEAD $CL_IN_EDIT work }
clcommit() { git commit -a --amend; clrebase }
gitlogall() { git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
gitlog() { gitlogall | head -n 40 }


# Android workflow
deploy_test() {
  scp out/target/product/cheets_arm/data/nativetest/$1/$1 $2:/home/chronos/user/android-data/data
  ssh $2 "chmod +x /home/chronos/user/android-data/data/$1"
}
run_test() { ssh $2 "android-sh -c \"/data/$1\"" }
bdr_test() { m $1 && deploy_test $1 $2 && exec_test $1 $2 }

get_manifest() {
  sso_client -location https://android-build.googleplex.com/builds/submitted/$1/cheets_arm-userdebug/latest/manifest_$1.xml > .repo/manifests/$1.xml
}


# Gerrit methods
gerrit_resubmit() {
	for cl in $(gerrit mine --raw); do
		if [[ "$(gerrit inspect $cl)" == *V:\ 1* ]]; then
			gerrit ready $cl 1;
		fi
	done
}

gerrit_submit() {
	for cl in $(gerrit mine --raw); do
		if [[ "$(gerrit inspect $cl)" == *CR:\ 2* ]]; then
			gerrit ready $cl 1; gerrit verify $cl 1;
		fi
	done
}


# Random helper to cause iterm to show a notification
notify() {
	($*);
	echo 'iterm-notify';
}