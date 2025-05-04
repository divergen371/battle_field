#!/bin/bash

# エラー時に停止
set -e

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Python環境の構築を開始します...${NC}"

# uvが既にインストールされているか確認
if command -v uv &> /dev/null; then
  echo -e "${GREEN}uvは既にインストールされています。${NC}"
else
  echo -e "${YELLOW}uvをインストールしています...${NC}"
  # uvのインストール
  curl -LsSf https://astral.sh/uv/install.sh | sh
  
  # PATHに追加（一時的）
  export PATH="$HOME/.cargo/bin:$PATH"
  
  # .bashrcまたは.zshrcにPATHを追加（永続的）
  if [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" "$HOME/.zshrc"; then
      echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.zshrc"
      echo "PATHを.zshrcに追加しました"
    fi
  elif [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "export PATH=\"\$HOME/.cargo/bin:\$PATH\"" "$HOME/.bashrc"; then
      echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
      echo "PATHを.bashrcに追加しました"
    fi
  fi
fi

# 仮想環境の作成
echo -e "${YELLOW}Python仮想環境を作成しています...${NC}"
uv venv .venv

# 仮想環境をアクティベート
source .venv/bin/activate

# 必要なパッケージのインストール
echo -e "${YELLOW}必要なPythonパッケージをインストールしています...${NC}"
uv pip install boto3 argparse

# requirements.txtの作成
echo -e "${YELLOW}requirements.txtを作成しています...${NC}"
cat > requirements.txt << EOF
boto3>=1.28.0
argparse>=1.4.0
EOF

echo -e "${GREEN}環境構築が完了しました！${NC}"
echo -e "${GREEN}使用方法:${NC}"
echo -e "${YELLOW}  source .venv/bin/activate    # 仮想環境をアクティベート${NC}"
echo -e "${YELLOW}  python scripts/setup_budgets.py --email your@email.com    # 予算設定実行${NC}"
echo -e "${YELLOW}  deactivate                   # 仮想環境を終了${NC}" 