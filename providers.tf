terraform {
  required_providers {
    onelogin = {
      source  = "onelogin/onelogin"
      version = "0.8.5"  
    }
  }
}

provider "onelogin" {
  apikey_auth = var.onelogin_access_token
}
