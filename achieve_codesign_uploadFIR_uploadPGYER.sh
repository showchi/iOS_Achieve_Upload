#! bin/bash
#Use:命令行进入项目目录执行
#param:
#   -p product #生产环境
#   -d development ＃测试环境
#   -l changelog #更新历史
#   -c channel #发布渠道，fir 或 pgyer
#   -h help ＃使用帮助
###############

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

###############设置需编译的项目配置名称
buildConfig="Release" #编译的方式,有Release,Debug，自定义的AdHoc等

#### pgyer.com 配置
pgyerAPIkey="yourAPIKey"
pgyerUserKey="yourUserKey"
pgyerUploadURL="http://www.pgyer.com/apiv1/app/upload"

#### fir.im 配置
firToken="yourFIRToken"

#### 证书签名 配置
codeSignIdentityDev="yourDevIdentity" #测试环境
provisioningProfileDev="yourDevProfile" #测试环境

codeSignIdentityPro="yourProductIdentity" #正式环境
provisioningProfilePro="yourProductProfile" #正式环境

projectName=`find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}'` #项目名称
projectDir=`pwd` #项目所在目录的绝对路径
exportIPADir=~/Documents/Achieves/$projectName-IPA #ipa，icon最后所在的目录绝对路径
isWorkSpace=true  #判断是用的workspace还是直接project，workspace设置为true，否则设置为false

while getopts c:l:dph opt
do
  case $opt in
    p)
      echo "开始编译生产环境"
      schemeName="$projectName" #生产环境
      codeSignIdentity="$codeSignIdentityPro"
      provisioningProfile="$provisioningProfilePro"
      path=$exportIPADir/$projectName-$(date +%Y%m%d%H%M%S).ipa
      ;;
    d)
      echo "开始编译测试环境"
      schemeName="$projectName Dev" #测试环境
      codeSignIdentity="$codeSignIdentityDev"
      provisioningProfile="$provisioningProfileDev"
      path=$exportIPADir/${projectName}-Dev-$(date +%Y%m%d%H%M%S).ipa
      ;;
    c)
      echo "发布渠道:$OPTARG"
      channel=$OPTARG
      ;;
    l)
      echo "更新历史:'$OPTARG'"
      changelog=$OPTARG
      ;;
    h)
      echo "#Use:命令行进入项目目录执行
      #param:
      #   -p product #生产环境
      #   -d development ＃测试环境
      #   -l changelog #更新历史
      #   -c channel #发布渠道，fir 或 pgyer
      #   -h help ＃使用帮助"
      exit 1
      ;;
    ?)
      echo "unknow argument"
      exit 1
      ;;
  esac
done

echo "~~~~~~~~~~~~~~~~~~~开始编译~~~~~~~~~~~~~~~~~~~"
if [ -d "$exportIPADir" ]; then
    echo $exportIPADir
	echo "文件目录存在"
else
	echo "文件目录不存在"
    mkdir -pv $exportIPADir
	echo "创建${exportIPADir}目录成功"
fi

###############进入项目目录
cd $projectDir
rm -rf ./build
buildAppToDir=$projectDir/build #编译打包完成后.app文件存放的目录

##############Pod install
echo "执行Pod install操作"
pod install --no-repo-update

###############获取版本号,bundleID
infoPlist="$projectName/Info.plist"
bundleVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoPlist`
bundleIdentifier=`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" $infoPlist`
bundleBuildVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoPlist`

###############开始编译app
if $isWorkSpace ; then  #判断编译方式
    echo  "开始编译workspace...."
    xcodebuild  -workspace $projectName.xcworkspace -scheme "$schemeName"  -configuration $buildConfig clean build CODE_SIGN_IDENTITY="$codeSignIdentity" PROVISIONING_PROFILE=$provisioningProfile SYMROOT=$buildAppToDir
else
    echo  "开始编译target...."
    xcodebuild  -target  "$schemeName"  -configuration $buildConfig clean build CODE_SIGN_IDENTITY="$codeSignIdentity" PROVISIONING_PROFILE=$provisioningProfile SYMROOT=$buildAppToDir
fi
#判断编译结果
if test $? -eq 0
then
echo "~~~~~~~~~~~~~~~~~~~编译成功~~~~~~~~~~~~~~~~~~~"
else
echo "~~~~~~~~~~~~~~~~~~~编译失败~~~~~~~~~~~~~~~~~~~"
exit 1
fi

###############开始打包成.ipa
ipaName=`echo $projectName | tr "[:upper:]" "[:lower:]"` #将项目名转小写
findFolderName=`find . -name "$buildConfig-*" -type d |xargs basename` #查找目录
appDir=$buildAppToDir/$findFolderName/  #app所在路径
echo "开始打包$projectName.app成$projectName.ipa....."
xcrun -sdk iphoneos PackageApplication -v $appDir/$projectName*.app -o $appDir/$ipaName.ipa #将app打包成ipa

###############开始拷贝到目标下载目录
#检查文件是否存在
if [ -f "$appDir/$ipaName.ipa" ]
then
echo "打包$ipaName.ipa成功."
else
echo "打包$ipaName.ipa失败."
exit 1
fi

cp -f -p $appDir/$ipaName.ipa $path   #拷贝ipa文件
echo "复制$ipaName.ipa到${exportIPADir}成功"
echo "~~~~~~~~~~~~~~~~~~~结束编译，处理成功~~~~~~~~~~~~~~~~~~~"
#open $exportIPADir

#####开始上传，如果只需要打ipa包出来不需要上传，可以删除下面的代码

if [ "$channel"x = "fir"x ]; then
  echo "正在上传到fir.im...."
  fir publish $path -T $firToken -c "$changelog"
  echo "\n打包上传更新成功！"
fi

if [ "$channel"x = "pgyer"x ]; then
  echo "正在上传到pgyer.com...."
  curl -F "file=@$path" -F "uKey=$pgyerUserKey" -F "_api_key=$pgyerAPIkey" $pgyerUploadURL
fi

#####清理
rm -rf $buildAppToDir
rm -rf $projectDir/tmp
