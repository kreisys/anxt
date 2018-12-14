{ pkgs }:

{ resource, module, ... }:

{ displayName, nixosConfig, keyName, s3Bucket, s3Prefix, securityGroups, subnetIds
, instanceType    ? "t2.micro"
, nixosRelease    ? "18.09"
, rootSize        ? 50
, spotPrice       ? 1.00
, minSize         ? 1
, maxSize         ? 1
, desiredCapacity ? 1 }:

assert builtins.isString s3Bucket;
assert builtins.isString s3Prefix;
assert builtins.isList securityGroups && securityGroups != [];
assert builtins.isList subnetIds && subnetIds != [];

let
  inherit (pkgs) lib runCommand;

  nixexprs = runCommand "exprs" {} ''
    mkdir -p $out
    cd $out
    echo '{}' > default.nix
    cp -r ${nixosConfig} nixos
  '';

  fixName      = name: builtins.replaceStrings [ " " "/" "\\"] [ "_" "-" "-" ] (lib.toLower name);
  resourceName = fixName displayName;

  anxt =
  module resourceName {
    source        = "${../.}";
    display_name  = displayName;
    nixos_release = nixosRelease;
    s3_bucket     = s3Bucket;
    inherit nixexprs;
  };

  launchConfiguration =
  let
    spotAttrs = lib.optionalAttrs (spotPrice != null) (assert builtins.isFloat spotPrice; {
      spot_price = toString spotPrice;
    });

    attrs = {
      instance_type        =  instanceType;
      key_name             =  keyName;
      security_groups      = securityGroups;
      name_prefix          =  "\${module.${resourceName}.name_prefix}";
      image_id             =  "\${module.${resourceName}.image_id}";
      iam_instance_profile =  "\${module.${resourceName}.iam_instance_profile}";
      user_data            =  "\${module.${resourceName}.userdata}";

      root_block_device = {
        volume_size = toString rootSize;
        volume_type = "gp2";
      };

      lifecycle = {
        create_before_destroy = true;
      };
    };
  in resource "aws_launch_configuration" resourceName (spotAttrs // attrs) [];

  autoscalingGroup =
  resource "aws_autoscaling_group" resourceName {
    vpc_zone_identifier  =  subnetIds;
    min_size             =  minSize;
    max_size             =  maxSize;
    desired_capacity     =  desiredCapacity;
    depends_on           =    ["module.${resourceName}"];
    name                 =  "\${aws_launch_configuration.${resourceName}.name}";
    launch_configuration =  "\${aws_launch_configuration.${resourceName}.name}";
    tags                 = ["\${module.${resourceName}.tags}"];
  } [];

in [ anxt launchConfiguration autoscalingGroup ]