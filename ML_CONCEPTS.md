# Fantasy Forecast as a Machine Learning Platform

## Overview
This platform demonstrates core machine learning concepts using Fantasy Premier League data.

## ML Concepts Demonstrated

### 1. Supervised Learning
**What it is**: Learning from labeled examples (input → output pairs)

**In our platform**:
- **Input (Features)**: Player's recent scores, opponent, availability
- **Output (Label)**: Actual gameweek score
- **Learning**: Each week provides new training data

### 2. Training vs Testing Data
**What it is**: Use past data to train, future data to test

**In our platform**:
- **Training Data**: Gameweeks 1-8 (past performances)
- **Test Data**: Gameweek 9 (make predictions, then compare)
- **Continuous Learning**: Each completed gameweek becomes training data

### 3. Feature Engineering
**What it is**: Creating useful inputs from raw data

**Current Features**:
```ruby
- avg_recent_score      # Average points last 3 games
- form_trend            # Is performance improving?
- availability          # Chance of playing
- opponent_difficulty   # Strength of opponent
- home_advantage        # Home vs away
```

**Future Features**:
```ruby
- minutes_played        # Game time consistency
- ownership_percentage  # Popularity (contrarian picks)
- price_changes         # Market sentiment
- goals_per_game        # Strike rate
- clean_sheets          # Defensive performance
```

### 4. Model Comparison
**What it is**: Testing different algorithms against each other

**Our Models**:
| Model | Algorithm | Strategy |
|-------|-----------|----------|
| ClaudeBot | Simple Average | `avg(last_3_games)` |
| GPTBot | Weighted Average | `3×last_game + 2×middle + 1×oldest` |
| Human | Expert Intuition | Pattern recognition + context |
| Future MLBot | Random Forest | Decision trees ensemble |

### 5. Evaluation Metrics
**What it is**: Measuring how good predictions are

**Our Metrics**:
- **Accuracy Score**: How close to actual performance
- **Total Score**: Accuracy × forecast count (rewards consistency)
- **Rank**: Overall leaderboard position

**Could Add**:
- **Mean Absolute Error (MAE)**: Average prediction error
- **Root Mean Square Error (RMSE)**: Penalizes large errors more
- **Precision/Recall**: For binary predictions (will score >5 points?)

### 6. Overfitting vs Generalization
**What it is**: Learning patterns vs memorizing noise

**Example**:
- **Overfitting**: "Salah always scores against Brighton" (too specific)
- **Generalization**: "Top midfielders score more against weak defenses" (useful pattern)

**In our platform**:
- ClaudeBot might overfit to recent lucky streaks
- GPTBot's recency weighting might generalize better
- Humans can overfit to narratives ("he's due a goal")

### 7. Ensemble Learning
**What it is**: Combining multiple models for better predictions

**Could Implement**:
```ruby
def ensemble_forecast
  # Average predictions from all bots
  claude_pred = ClaudeBot.predict(player)
  gpt_pred = GPTBot.predict(player)
  ml_pred = MLBot.predict(player)

  # Weighted ensemble (better models get more weight)
  (claude_pred × 0.3) + (gpt_pred × 0.5) + (ml_pred × 0.2)
end
```

### 8. Online Learning
**What it is**: Model updates continuously as new data arrives

**In our platform**:
- Each completed gameweek → new training data
- Retrain models weekly
- Adapt to meta changes (new players, injuries, form shifts)

## Building a Real ML Model

### Step 1: Collect More Features
```ruby
# app/services/ml_feature_extractor.rb
def extract_features(player, gameweek)
  {
    # Historical performance
    avg_last_3: player.avg_points(last: 3),
    avg_last_5: player.avg_points(last: 5),
    form_trend: player.form_trend,

    # Opposition
    opponent_strength: opponent.defensive_rating,
    home_advantage: player.is_home? ? 1 : 0,

    # Player attributes
    minutes_percentage: player.minutes / 90.0,
    goals_per_90: player.goals / (player.minutes / 90.0),

    # Market signals
    ownership: player.ownership_percentage,
    price_trend: player.price_changes_last_week
  }
end
```

### Step 2: Train a Model (Python)
```python
# ml/train_model.py
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split

# Load data
df = pd.read_csv('training_data.csv')

# Features and target
X = df[['avg_last_3', 'avg_last_5', 'form_trend',
        'opponent_strength', 'home_advantage', 'minutes_percentage']]
y = df['actual_points']

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

# Train model
model = RandomForestRegressor(n_estimators=100)
model.fit(X_train, y_train)

# Evaluate
score = model.score(X_test, y_test)
print(f"R² Score: {score}")

# Save model
import joblib
joblib.dump(model, 'fpl_model.pkl')
```

### Step 3: Integrate with Rails
```ruby
# app/services/ai_forecasting_service.rb
def self.generate_ml_forecasts(ai_user, next_gameweek, recent_gameweeks)
  # Extract features for all players
  features = extract_features_for_ml(next_gameweek)

  # Call Python ML model
  predictions = call_python_model(features)

  # Select top predictions by position
  create_forecasts_from_predictions(predictions, ai_user, next_gameweek)
end
```

## Educational Value

### For Beginners:
- **See ML in action**: Real predictions, real results
- **Understand evaluation**: Why accuracy matters
- **Compare approaches**: Human vs algorithm

### For Intermediate:
- **Feature engineering**: What makes a good feature?
- **Model comparison**: Which algorithm works best?
- **Bias-variance tradeoff**: Simple vs complex models

### For Advanced:
- **Ensemble methods**: Combine multiple approaches
- **Time series**: Temporal dependencies matter
- **Transfer learning**: Use general football knowledge

## Future Enhancements

### 1. Model Explainability
Show WHY the AI picked each player:
```
ClaudeBot picked Salah because:
✓ Averaged 12.3 points last 3 games (highest)
✓ 100% chance of playing
✗ Tough opponent (Man City)
→ Confidence: 85%
```

### 2. A/B Testing
Run multiple strategies simultaneously:
- ClaudeBot v1 (current)
- ClaudeBot v2 (with opponent difficulty)
- ClaudeBot v3 (with home/away split)

### 3. Reinforcement Learning
Bot learns from mistakes:
- High confidence but wrong? → Reduce weight on that feature
- Low confidence but right? → Increase weight on that feature

### 4. Interactive Learning
Let users:
- Adjust bot strategies
- Add custom features
- See how changes affect predictions

## Real-World Applications

This same approach is used for:
- **Stock market prediction**: Historical prices → future prices
- **Weather forecasting**: Past conditions → future weather
- **Recommendation systems**: Past behavior → future preferences
- **Medical diagnosis**: Symptoms → disease probability

## Conclusion

Your Fantasy Forecast platform is a **perfect ML sandbox** because:
1. ✅ Clear problem (predict player performance)
2. ✅ Measurable outcomes (actual scores)
3. ✅ Regular feedback (weekly results)
4. ✅ Multiple approaches (human vs AI)
5. ✅ Growing dataset (more data each week)
6. ✅ Engaging domain (football is fun!)

You're essentially running a **Kaggle competition** where anyone can submit their "model" (human or AI) and compete on the same dataset!
