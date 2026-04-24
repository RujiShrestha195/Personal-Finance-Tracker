from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import re

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///finance_tracker.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Database Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    phone_number = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    
    transactions = db.relationship('Transaction', backref='user', lazy=True)
    goals = db.relationship('Goal', backref='user', lazy=True)

class Transaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    type = db.Column(db.String(20), nullable=False)  # 'Income' or 'Expense'
    amount = db.Column(db.Float, nullable=False)
    category = db.Column(db.String(50), nullable=False)
    date = db.Column(db.Date, nullable=False)
    description = db.Column(db.String(500))
    transaction_type = db.Column(db.String(20), nullable=False)  # 'Cash' or 'Online'
    screenshot_path = db.Column(db.String(500))

class Goal(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    target_amount = db.Column(db.Float, nullable=False)
    saved_amount = db.Column(db.Float, default=0.0)
    target_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.String(500))
    is_reached = db.Column(db.Boolean, default=False)

def validate_nepali_phone(phone):
    """Validate Nepalese phone number (10 digits, starting with 98 or 97)"""
    pattern = r'^(98|97)\d{8}$'
    return bool(re.match(pattern, phone))

def validate_email(email):
    """Basic email validation"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))

# API Endpoints

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Missing request body or invalid JSON'}), 400

    full_name = data.get('fullName', '').strip()
    email = data.get('email', '').strip()
    phone_number = data.get('phoneNumber', '').strip()
    password = data.get('password', '')
    confirm_password = data.get('confirmPassword', '')

    if not all([full_name, email, phone_number, password, confirm_password]):
        return jsonify({'error': 'All fields are required'}), 400

    if len(password) < 8:
        return jsonify({'error': 'Password must be at least 8 characters'}), 400

    if password != confirm_password:
        return jsonify({'error': 'Passwords do not match'}), 400

    if User.query.filter_by(email=email).first() or User.query.filter_by(phone_number=phone_number).first():
        return jsonify({'error': 'This email or phone number is already registered'}), 409

    password_hash = generate_password_hash(password)
    new_user = User(
        full_name=full_name,
        email=email,
        phone_number=phone_number,
        password_hash=password_hash
    )

    try:
        db.session.add(new_user)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        print(f"Database error during registration: {e}")
        return jsonify({'error': 'A server error occurred during registration.'}), 500

    return jsonify({
        'message': 'User registered successfully',
        'user_id': new_user.id,
        'full_name': new_user.full_name
    }), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    email_or_phone = data.get('email_or_phone', '').strip()
    password = data.get('password', '')
    
    if not email_or_phone or not password:
        return jsonify({'error': 'Email/Phone and password are required'}), 400
    
    user = User.query.filter(
        (User.email == email_or_phone) | (User.phone_number == email_or_phone)
    ).first()
    
    if not user or not check_password_hash(user.password_hash, password):
        return jsonify({'error': 'Email or phone number not registered'}), 401
    
    return jsonify({
        'message': 'Login successful',
        'user_id': user.id,
        'full_name': user.full_name,
        'email': user.email,
        'phone_number': user.phone_number
    }), 200

@app.route('/api/summary/<int:user_id>', methods=['GET'])
def get_summary(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    transactions = Transaction.query.filter_by(user_id=user_id).all()
    total_income = sum(t.amount for t in transactions if t.type == 'Income')
    total_expense = sum(t.amount for t in transactions if t.type == 'Expense')
    total_balance = total_income - total_expense
    
    return jsonify({
        'total_income': total_income,
        'total_expense': total_expense,
        'total_balance': total_balance
    }), 200

@app.route('/api/transactions/recent/<int:user_id>', methods=['GET'])
def get_recent_transactions(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    transactions = Transaction.query.filter_by(user_id=user_id)\
        .order_by(Transaction.date.desc(), Transaction.id.desc())\
        .all()
    
    result = []
    for t in transactions:
        result.append({
            'id': t.id,
            'type': t.type,
            'amount': t.amount,
            'category': t.category,
            'date': t.date.isoformat(),
            'description': t.description,
            'transaction_type': t.transaction_type
        })
    
    return jsonify({'transactions': result}), 200

@app.route('/api/transactions', methods=['POST'])
def add_transaction():
    data = request.get_json()
    user_id = data.get('user_id')
    transaction_type = data.get('type')
    amount = data.get('amount')
    category = data.get('category')
    date_str = data.get('date')
    description = data.get('description', '')
    transaction_type_payment = data.get('transaction_type')
    
    if not user_id:
        return jsonify({'error': 'User ID is required'}), 400
    
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    try:
        date = datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
    
    new_transaction = Transaction(
        user_id=user_id,
        type=transaction_type,
        amount=float(amount),
        category=category,
        date=date,
        description=description,
        transaction_type=transaction_type_payment
    )
    
    db.session.add(new_transaction)
    db.session.commit()
    
    return jsonify({'message': 'Transaction added successfully', 'transaction_id': new_transaction.id}), 201

@app.route('/api/transactions/<int:transaction_id>', methods=['PUT'])
def update_transaction(transaction_id):
    transaction = Transaction.query.get(transaction_id)
    if not transaction:
        return jsonify({'error': 'Transaction not found'}), 404
    
    data = request.get_json()
    if 'amount' in data: transaction.amount = float(data.get('amount'))
    if 'category' in data: transaction.category = data.get('category')
    if 'date' in data:
        try:
            transaction.date = datetime.strptime(data.get('date'), '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format'}), 400
    if 'description' in data: transaction.description = data.get('description')
    if 'transaction_type' in data: transaction.transaction_type = data.get('transaction_type')
    if 'type' in data: transaction.type = data.get('type')
    
    db.session.commit()
    return jsonify({'message': 'Transaction updated successfully'}), 200

@app.route('/api/goals', methods=['POST'])
def create_goal():
    data = request.get_json()
    user_id = data.get('user_id')
    name = data.get('name', '').strip()
    target_amount = data.get('target_amount')
    target_date_str = data.get('target_date')
    
    if not user_id: return jsonify({'error': 'User ID is required'}), 400
    user = User.query.get(user_id)
    if not user: return jsonify({'error': 'User not found'}), 404
    
    try:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
    
    new_goal = Goal(
        user_id=user_id,
        name=name,
        target_amount=float(target_amount),
        target_date=target_date,
        description=data.get('description', ''),
        saved_amount=float(data.get('saved_amount', 0.0))
    )
    
    db.session.add(new_goal)
    db.session.commit()
    return jsonify({'message': 'Goal created successfully', 'goal_id': new_goal.id}), 201

@app.route('/api/goals/<int:goal_id>', methods=['PUT'])
def update_goal(goal_id):
    goal = Goal.query.get(goal_id)
    if not goal: return jsonify({'error': 'Goal not found'}), 404
    
    data = request.get_json()
    if 'name' in data: goal.name = data.get('name')
    if 'target_amount' in data: goal.target_amount = float(data.get('target_amount'))
    if 'saved_amount' in data: goal.saved_amount = float(data.get('saved_amount'))
    if 'target_date' in data:
        try:
            goal.target_date = datetime.strptime(data.get('target_date'), '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format'}), 400
    if 'is_reached' in data: goal.is_reached = data.get('is_reached')
    
    db.session.commit()
    return jsonify({'message': 'Goal updated successfully'}), 200

@app.route('/api/goals/<int:goal_id>', methods=['DELETE'])
def delete_goal(goal_id):
    goal = Goal.query.get(goal_id)
    if not goal: return jsonify({'error': 'Goal not found'}), 404
    db.session.delete(goal)
    db.session.commit()
    return jsonify({'message': 'Goal deleted successfully'}), 200

@app.route('/api/goals/user/<int:user_id>', methods=['GET'])
def get_user_goals(user_id):
    goals = Goal.query.filter_by(user_id=user_id).all()
    result = []
    for goal in goals:
        result.append({
            'id': goal.id,
            'name': goal.name,
            'target_amount': goal.target_amount,
            'saved_amount': goal.saved_amount,
            'target_date': goal.target_date.isoformat(),
            'description': goal.description,
            'is_reached': goal.is_reached
        })
    return jsonify({'goals': result}), 200

@app.route('/api/profile/update/<int:user_id>', methods=['POST'])
def update_profile(user_id):
    user = User.query.get(user_id)
    if not user: return jsonify({'error': 'User not found'}), 404
    data = request.get_json()
    if 'full_name' in data: user.full_name = data.get('full_name').strip()
    if 'password' in data: user.password_hash = generate_password_hash(data.get('password'))
    db.session.commit()
    return jsonify({'message': 'Profile updated successfully'}), 200

with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
