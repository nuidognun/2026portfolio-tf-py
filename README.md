# 2026portfolio-tf-py
本リポジトリは、ポートフォリオサイトのインフラ（AWS）をコード管理したTerraform一式、および画像処理/通知を担うLambdaのプログラムです

├── terraform/
│   ├── provider.tf      # プロバイダー定義
│   ├── s3.co.jp.tf      # S3バケット・ポリシー設定
│   ├── sqs.tf           # SQS（ディレイキュー）設定
│   └── lambda.tf        # Lambda関数・IAMロール設定
└── lambda/
    └── index.py         # 画像一括アップロード多重通知制御プログラム
