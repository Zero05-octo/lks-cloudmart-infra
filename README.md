# 🏗️ CloudMart — Infra Repository (Terraform)

Repository ini berisi kode **Infrastructure as Code (IaC)** menggunakan **Terraform** untuk seluruh kebutuhan infrastruktur AWS CloudMart.

---

## 📁 Struktur Direktori

```
infra/
├── backend.tf          ← Konfigurasi remote state S3 (isi TODO)
├── main.tf             ← Resource Terraform (lengkapkan 8 section TODO)
├── variables.tf        ← Input variables
├── outputs.tf          ← Output values
└── .github/
    ├── workflows/
    │   ├── classroom.yml   ← ⛔ DILARANG DIUBAH (Autograding Juri)
    │   └── deploy.yml      ← ✏️ Lengkapi TODO pipeline Terraform
    ├── classroom/          ← ⛔ DILARANG DIUBAH
    └── scripts/            ← ⛔ DILARANG DIUBAH
```

---

## 🚀 Panduan Eksekusi

### 1. Inisialisasi Backend S3
Buat S3 bucket di AWS Console:
- Name: `lks-mart-tfstate-<KotaAnda-NamaAnda>`
- Region: `us-east-1`
- Versioning: `Enabled`

Lalu update `backend.tf`.

### 2. Testing Lokal
```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Otomatisasi CI/CD
Lengkapi file `.github/workflows/deploy.yml` dengan langkah-langkah Terraform init, validate, plan, dan apply.
