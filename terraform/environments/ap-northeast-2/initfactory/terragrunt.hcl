terraform {
  source = "../../../modules/spacemesh-initfactory/"
}

dependencies {
  paths = [
    "../../us-east-1/mgmt/",
  ]
}

include {
  path = find_in_parent_folders()
}

# vim:filetype=terraform ts=2 sw=2 et:
