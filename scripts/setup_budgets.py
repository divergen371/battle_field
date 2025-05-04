#!/usr/bin/env python3
import boto3
import argparse
import json
from datetime import datetime

def create_budget(name, limit_amount, time_unit, email):
    """AWSの予算とアラームを作成する"""
    client = boto3.client('budgets')
    
    # 予算とアラートの作成
    response = client.create_budget(
        AccountId=boto3.client('sts').get_caller_identity().get('Account'),
        Budget={
            'BudgetName': name,
            'BudgetLimit': {
                'Amount': str(limit_amount),
                'Unit': 'USD'
            },
            'TimeUnit': time_unit,
            'BudgetType': 'COST',
            'CostTypes': {
                'IncludeTax': True,
                'IncludeSubscription': True,
                'UseBlended': False,
                'IncludeRefund': False,
                'IncludeCredit': False,
                'IncludeUpfront': True,
                'IncludeRecurring': True,
                'IncludeOtherSubscription': True,
                'IncludeSupport': True,
                'IncludeDiscount': True,
                'UseAmortized': False
            }
        },
        NotificationsWithSubscribers=[
            {
                'Notification': {
                    'NotificationType': 'ACTUAL',
                    'ComparisonOperator': 'GREATER_THAN',
                    'Threshold': 80.0,
                    'ThresholdType': 'PERCENTAGE',
                    'NotificationState': 'ALARM'
                },
                'Subscribers': [
                    {
                        'SubscriptionType': 'EMAIL',
                        'Address': email
                    }
                ]
            },
            {
                'Notification': {
                    'NotificationType': 'ACTUAL',
                    'ComparisonOperator': 'GREATER_THAN',
                    'Threshold': 100.0,
                    'ThresholdType': 'PERCENTAGE',
                    'NotificationState': 'ALARM'
                },
                'Subscribers': [
                    {
                        'SubscriptionType': 'EMAIL',
                        'Address': email
                    }
                ]
            }
        ]
    )
    return response

def main():
    parser = argparse.ArgumentParser(description='AWSの予算とアラームを設定')
    parser.add_argument('--email', required=True, help='通知先のメールアドレス')
    args = parser.parse_args()
    
    print("AWS予算設定スクリプト - ペネトレーションテスト環境")
    
    try:
        # 月次予算（10 USD）
        monthly_response = create_budget(
            name=f"pentest-lab-monthly-budget-{datetime.now().strftime('%Y%m')}",
            limit_amount=10.0,
            time_unit='MONTHLY',
            email=args.email
        )
        
        # 日次予算（1 USD）
        daily_response = create_budget(
            name=f"pentest-lab-daily-budget-{datetime.now().strftime('%Y%m%d')}",
            limit_amount=1.0,
            time_unit='DAILY',
            email=args.email
        )
        
        print(f"月次予算（10 USD）を作成しました: {monthly_response['BudgetName']}")
        print(f"日次予算（1 USD）を作成しました: {daily_response['BudgetName']}")
        print(f"予算超過時は {args.email} に通知されます")
        print("注意: 予算アラームの反映には数時間かかる場合があります")
    
    except Exception as e:
        print(f"エラーが発生しました: {str(e)}")
        print("必要なIAM権限: budgets:CreateBudget, sts:GetCallerIdentity")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main()) 