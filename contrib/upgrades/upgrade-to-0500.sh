#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env

docker exec -i $(container_name database-1) psql -U postgres bitcart <<EOF
ALTER TABLE discountsxproducts RENAME CONSTRAINT discountsxproducts_discount_id_fkey TO discountsxproducts_discount_id_discounts_fkey;
ALTER TABLE discountsxproducts RENAME CONSTRAINT discountsxproducts_product_id_fkey TO discountsxproducts_product_id_products_fkey;
ALTER TABLE discounts RENAME CONSTRAINT discounts_user_id_fkey TO discounts_user_id_users_fkey;
ALTER TABLE paymentmethods RENAME CONSTRAINT paymentmethods_invoice_id_fkey TO paymentmethods_invoice_id_invoices_fkey;
ALTER TABLE productsxinvoices RENAME CONSTRAINT productsxinvoices_invoice_id_fkey TO productsxinvoices_invoice_id_invoices_fkey;
ALTER TABLE invoices RENAME CONSTRAINT invoices_store_id_fkey TO invoices_store_id_stores_fkey;
ALTER TABLE invoices RENAME CONSTRAINT invoices_user_id_fkey TO invoices_user_id_users_fkey;
ALTER TABLE notificationsxstores RENAME CONSTRAINT notificationsxstores_notification_id_fkey TO notificationsxstores_notification_id_notifications_fkey;
ALTER TABLE notifications RENAME CONSTRAINT notifications_user_id_fkey TO notifications_user_id_users_fkey;
ALTER TABLE notificationsxstores RENAME CONSTRAINT notificationsxstores_store_id_fkey TO notificationsxstores_store_id_stores_fkey;
ALTER TABLE productsxinvoices RENAME CONSTRAINT productsxinvoices_product_id_fkey TO productsxinvoices_product_id_products_fkey;
ALTER TABLE products RENAME CONSTRAINT products_store_id_fkey TO products_store_id_stores_fkey;
ALTER TABLE products RENAME CONSTRAINT products_user_id_fkey TO products_user_id_users_fkey;
ALTER TABLE walletsxstores RENAME CONSTRAINT walletsxstores_store_id_fkey TO walletsxstores_store_id_stores_fkey;
ALTER TABLE stores RENAME CONSTRAINT stores_user_id_fkey TO stores_user_id_users_fkey;
ALTER TABLE templates RENAME CONSTRAINT templates_user_id_fkey TO templates_user_id_users_fkey;
ALTER TABLE wallets RENAME CONSTRAINT wallets_user_id_fkey TO wallets_user_id_users_fkey;
ALTER TABLE tokens RENAME CONSTRAINT tokens_user_id_fkey TO tokens_user_id_users_fkey;
ALTER TABLE walletsxstores RENAME CONSTRAINT walletsxstores_wallet_id_fkey TO walletsxstores_wallet_id_wallets_fkey;
EOF

docker top $(container_name worker-1) >/dev/null 2>&1 && docker exec -i $(container_name worker-1) python3 <<EOF
import asyncio

from api import models, settings


async def update_templates(model):
    for obj in await model.query.gino.all():
        templates = obj.templates.copy() if obj.templates else {}
        for key in templates:
            templates[key] = str(templates[key])
        await obj.update(templates=templates).apply()


async def main():
    print("Updating configured templates...")
    await settings.init_db()
    await update_templates(models.Store)
    await update_templates(models.Product)
    print("Updating templates done")


asyncio.run(main())
EOF
