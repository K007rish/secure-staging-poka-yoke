#author krish sutariya
terraform {
  required_version = ">=1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.1"
    }
  }
}
provider "google" {
  project = var.project_id
  region  = var.region
}
#define variables

variable "project_id" {
  description = "google project1"
  type        = string
}
variable "region" {
  description = "google cloud region."
  type        = string
  default     = "asia-south1"

}
variable "raw_bucket_name" {
  description = " D0 raw landing bucket."
  type        = string
}
resource "google_storage_bucket" "d0_raw_landing" {
  name     = var.raw_bucket_name
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
  # retention_period = 30 days
  retention_policy {
    retention_period = 2592000
  }
}

resource "google_service_account" "ingestion" {

  account_id   = "d0-raw-ingestion"
  display_name = "d0 raw landing ingestion"
  project      = var.project_id
}
resource "google_storage_bucket_iam_member" "raw_ingest" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.ObjectCreator"
  member = "serviceAccount:${google_service_account.ingestion.email}"
  condition {
    title       = "RawIngestPrefix"
    description = "allow only creation"
    expression  = "resource.name.startsWith(\"${google_storage_bucket.d0_raw_landing.name}/objects/raw/\")"

  }
}

#d1bigquery
resource "google_bigquery_dataset" "d1_staged_enforced" {
  project    = var.project_id
  dataset_id = "d1_staged_enforced"
  location   = var.region

  description                 = "human readable description to the BigQuery dataset"
  delete_contents_on_destroy  = false
  default_table_expiration_ms = 31536000000
}
resource "google_bigquery_table" "student_onboarding" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id   = "student_onboarding"

  deletion_protection = true

  schema = jsonencode([
    {
      name = "student_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "tenant_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "full_name"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "email"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "date_of_birth"
      type = "DATE"
      mode = "REQUIRED"
    },
    {
      name = "phone_number"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "consent_given"
      type = "BOOL"
      mode = "REQUIRED"
    },
    {
      name = "identity_verified"
      type = "BOOL"
      mode = "REQUIRED"
    },
    {
      name = "document_submitted"
      type = "BOOL"
      mode = "REQUIRED"
    },
    {
      name = "fee_paid"
      type = "BOOL"
      mode = "REQUIRED"
    },
    {
      name = "onboarding_decision"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "ingested_at"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    }
  ])

  time_partitioning {
    type  = "DAY"
    field = "ingested_at"
  }

  require_partition_filter = true

  depends_on = [
    google_bigquery_dataset.d1_staged_enforced
  ]
}
resource "google_bigquery_row_access_policy" "analytics_tenant_a" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id   = google_bigquery_table.student_onboarding.table_id

  policy_id        = "analytics_tenant_a"
  filter_predicate = "tenant_id = 'tenant-a'"

  grantees = [
    "group:${var.analytics_group}"
  ]
}
variable "analytics_group" {
  description = "authorized to access d1"
  type        = string

}
resource "google_bigquery_dataset_iam_member" "analytics_reader" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id

  role   = "roles/bigquery.dataviewer"
  member = "group:${var.analytics_group}"
}