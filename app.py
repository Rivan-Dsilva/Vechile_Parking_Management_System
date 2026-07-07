from flask import Flask, request, jsonify
import mysql.connector
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ---------------------------
# DATABASE CONFIGURATION
# ---------------------------
db_config = {
    "host": "localhost",
    "user": "root",
    "password": "*****", #Enter password
    "database": "parking_system"
}

def get_db_connection():
    return mysql.connector.connect(**db_config)

# ---------------------------
# ADD ENTRY
# ---------------------------
@app.route('/add_entry', methods=['POST'])
def add_entry():
    data = request.json
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    
    try:
        # 1. Insert the parking record
        sql = """
        INSERT INTO parking_records 
        (customer_id, name, mobile, address, vehicle_number, vehicle_type, slot_id, entry_time)
        VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
        """
        values = (
            data['customerID'], data['name'], data['mobile'], 
            data.get('address', ''), data['vehNum'], data['type'], data['slot']
        )
        cursor.execute(sql, values)

        # 2. Mark slot as occupied
        cursor.execute(
            "UPDATE parking_slots SET status = 'occupied' WHERE slot_id = %s",
            (data['slot'],)
        )

        db.commit()
        return jsonify({"status": "success", "message": "Entry recorded"})

    except Exception as e:
        db.rollback()
        print(f"Error in add_entry: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()

# ---------------------------
# EXIT VEHICLE
# ---------------------------
@app.route('/exit_vehicle', methods=['POST'])
def exit_vehicle():
    data = request.json
    veh_num = data['vehNum']
    txn_id = data['txnId']
    
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        # 1. Find the latest active record for this vehicle
        cursor.execute("""
            SELECT id, slot_id FROM parking_records 
            WHERE vehicle_number = %s AND exit_time IS NULL 
            ORDER BY id DESC LIMIT 1
        """, (veh_num,))
        
        record = cursor.fetchone()

        if not record:
            return jsonify({"error": "Vehicle not found in active records"}), 404

        # 2. Update record (Trigger 'calculate_amount' will fire here)
        cursor.execute("""
            UPDATE parking_records 
            SET exit_time = NOW(), transaction_id = %s 
            WHERE id = %s
        """, (txn_id, record['id']))

        # 3. Free the slot
        cursor.execute(
            "UPDATE parking_slots SET status = 'available' WHERE slot_id = %s",
            (record['slot_id'],)
        )

        db.commit()
        return jsonify({"status": "success", "transaction_id": txn_id})

    except Exception as e:
        db.rollback()
        print(f"Error in exit_vehicle: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        db.close()

# ---------------------------
# GET ALL SLOTS
# ---------------------------
@app.route('/get_slots', methods=['GET'])
def get_slots():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM parking_slots")
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        db.close()

# ---------------------------
# GET ACTIVE VEHICLES
# ---------------------------
@app.route('/get_active', methods=['GET'])
def get_active():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM parking_records WHERE exit_time IS NULL")
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        db.close()

# ---------------------------
# GET HISTORY
# ---------------------------
@app.route('/get_history', methods=['GET'])
def get_history():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT transaction_id, customer_id, name, vehicle_number, slot_id, amount, entry_time, exit_time
            FROM parking_records 
            WHERE exit_time IS NOT NULL 
            ORDER BY exit_time DESC
        """)
        return jsonify(cursor.fetchall())
    finally:
        cursor.close()
        db.close()

if __name__ == "__main__":
    app.run(debug=True, port=5000)
