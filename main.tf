terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "0.2.5"
    }
    azurerm = {
      version = "2.29.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.myworkspace.id
}


resource "azurerm_databricks_workspace" "myworkspace" {
  location            = var.location
  name                = "ig-test-workspace"
  resource_group_name = var.azurerm_resource_group
  sku                 = "trial"
}

resource "databricks_cluster" "shared_autoscaling" {
  cluster_name            = "ig-test-workspace-Autoscaling-Cluster"
  spark_version           = var.spark_version
  node_type_id            = var.node_type_id
  autotermination_minutes = 90
  autoscale {
    min_workers = var.min_workers
    max_workers = var.max_workers
  }
}

resource "databricks_group" "db-group" {
  display_name               = "adb-users-admin"
  allow_cluster_create       = true
  allow_instance_pool_create = true
  depends_on = [
    resource.azurerm_databricks_workspace.myworkspace
  ]
}

resource "databricks_notebook" "notebook" {
  content   = base64encode("print('Welcome to your Python notebook')")
  path      = var.notebook_path
  overwrite = false
  mkdirs    = true
  language  = "PYTHON"
  format    = "SOURCE"
}

resource "databricks_job" "myjob" {
  name                = "Featurization"
  timeout_seconds     = 3600
  max_retries         = 1
  max_concurrent_runs = 1
  existing_cluster_id = databricks_cluster.shared_autoscaling.id

  notebook_task {
    notebook_path = var.notebook_path
  }

  email_notifications {
    no_alert_for_skipped_runs = true
  }
}