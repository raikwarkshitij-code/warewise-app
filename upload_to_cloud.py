import os
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

# --- DEBUGGING LINES ---
key_path = "serviceAccountKey.json"
print("Looking for key at:", os.path.abspath(key_path))
# -----------------------

# 1. Authenticate
cred = credentials.Certificate(key_path)
firebase_admin.initialize_app(cred)
db = firestore.client()


# 2. Load the CSV Data
print("Reading warewise_master_inventory.csv...")
df = pd.read_csv("warewise_master_inventory.csv")

# 3. Prepare the Batch Uploader
batch = db.batch()
processed_count = 0

print("Transmitting data to Firestore...")
for index, row in df.iterrows():
    sku = str(row['id'])
    price = float(row['price'])
    city_stock = {
        'Berlin': int(row['berlinStock']),
        'Munich': int(row['munichStock']),
        'Hamburg': int(row['hamburgStock']),
    }

    # Construct the JSON payload for WareWise
    payload = {
        'sku': sku,
        'name': str(row['name']),
        'category': str(row['category']),
        'price': price,
        'cityStock': city_stock,
        'quantity': sum(city_stock.values()),
        'threshold': int(row['minStock']),
    }

    restricted_payload = {
        'supplierName': str(row['supplierName']),
        'costPerUnit': round(price * 0.6, 2),
        'leadTimeDays': int(row['leadTime']),
        'contactPerson': str(row['contactPerson']),
        'email': str(row['email']),
        'phone': str(row['phone']),
        'address': str(row['address']),
    }

    doc_ref = db.collection('products').document(sku)
    batch.set(doc_ref, payload)
    batch.set(doc_ref.collection('restricted').document('cost'), restricted_payload)
    processed_count += 1

    if processed_count % 200 == 0:
        batch.commit()
        print(f"Committed {processed_count} records...")
        batch = db.batch()

batch.commit()
print(f"✅ SUCCESS! {processed_count} total products pushed to WareWise Cloud.")
