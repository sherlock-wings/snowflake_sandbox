# Bluesky Analytics Dashboard

Interactive analytics dashboard for exploring Bluesky social media data, built with Streamlit and powered by Snowflake.

## Features

- 📈 Posts and engagement trends over time
- #️⃣ Top hashtag analysis
- ⏰ Engagement patterns by hour
- 👥 User growth tracking
- 📋 Raw data exploration

## Local Development

### Prerequisites

- Python 3.9+
- Snowflake account with Bluesky data

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/patrickfcallahan/bluesky-analytics.git
   cd bluesky-analytics
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Configure Snowflake credentials:
   ```bash
   cp .streamlit/secrets.toml.example .streamlit/secrets.toml
   # Edit .streamlit/secrets.toml with your credentials
   ```

5. Run the app:
   ```bash
   streamlit run app.py
   ```

## Deployment to Streamlit Cloud

1. Push this repo to GitHub
2. Go to [share.streamlit.io](https://share.streamlit.io)
3. Click "New app" and select your repo
4. Add Snowflake credentials in **Settings → Secrets**:
   ```toml
   [snowflake]
   user = "your_username"
   password = "your_password"
   account = "your_account.region"
   warehouse = "your_warehouse"
   database = "your_database"
   schema = "your_schema"
   ```
5. Deploy!

## Customizing Queries

Replace the demo data in `app.py` with your actual Snowflake queries. Example:

```python
@st.cache_data(ttl=3600)
def get_posts_over_time():
    query = """
    SELECT 
        DATE_TRUNC('day', created_at) as date,
        COUNT(*) as posts,
        COUNT(DISTINCT author_did) as unique_users
    FROM bluesky.posts
    WHERE created_at >= DATEADD(day, -30, CURRENT_DATE())
    GROUP BY 1
    ORDER BY 1
    """
    return run_query(query)
```

## License

MIT

## Author

[Patrick F. Callahan](https://patrick-f-callahan.com)
