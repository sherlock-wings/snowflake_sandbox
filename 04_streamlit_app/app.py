"""
Bluesky Analytics Dashboard
A Streamlit application for exploring Bluesky social media data with NLP sentiment analysis.

Data sources (pre-computed in Snowflake for performance):
- RPT_DAILY_SUMMARY: Daily post counts and sentiment
- RPT_SENTIMENT_BY_LANGUAGE: Sentiment breakdown by language
- RPT_EXTERNAL_DOMAINS: Most shared external links
- RPT_POSTING_HEATMAP: Activity patterns by day/hour
- RPT_CONFIDENCE_DISTRIBUTION: Model confidence histogram
- RPT_DAILY_TOP_NGRAMS: Trending keywords over time
- RPT_THREAD_SENTIMENT: Reply thread sentiment patterns
- RPT_HIGH_CONFIDENCE_POSTS: Sample high-confidence posts
- RPT_NGRAM_SENTIMENT: Keyword sentiment summary
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import numpy as np

# ============================================
# Page Configuration
# ============================================
st.set_page_config(
    page_title="Bluesky NLP Analytics",
    page_icon="🦋",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================
# Snowflake Connection
# ============================================
@st.cache_resource
def get_snowflake_connection():
    """
    Establish connection to Snowflake using Streamlit secrets.
    Supports both password and key-pair authentication.
    """
    try:
        import snowflake.connector
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.backends import default_backend
        
        sf_config = st.secrets["snowflake"]
        
        # Base connection parameters
        conn_params = {
            "user": sf_config["user"],
            "account": sf_config["account"],
            "warehouse": sf_config["warehouse"],
            "database": sf_config["database"],
            "schema": sf_config["schema"],
            "role": sf_config.get("role", "DEV_FR"),
        }
        
        # Key-pair authentication
        if "private_key_path" in sf_config:
            with open(sf_config["private_key_path"], "rb") as key_file:
                passphrase = sf_config.get("private_key_passphrase", "").encode() or None
                private_key = serialization.load_pem_private_key(
                    key_file.read(),
                    password=passphrase,
                    backend=default_backend()
                )
                conn_params["private_key"] = private_key.private_bytes(
                    encoding=serialization.Encoding.DER,
                    format=serialization.PrivateFormat.PKCS8,
                    encryption_algorithm=serialization.NoEncryption()
                )
        elif "private_key" in sf_config:
            # Inline private key (for Streamlit Cloud)
            passphrase = sf_config.get("private_key_passphrase", "").encode() or None
            private_key = serialization.load_pem_private_key(
                sf_config["private_key"].encode(),
                password=passphrase,
                backend=default_backend()
            )
            conn_params["private_key"] = private_key.private_bytes(
                encoding=serialization.Encoding.DER,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
        else:
            # Password authentication fallback
            conn_params["password"] = sf_config["password"]
        
        conn = snowflake.connector.connect(**conn_params)
        return conn
    except Exception as e:
        st.error(f"Failed to connect to Snowflake: {e}")
        return None


@st.cache_data(ttl=3600)  # Cache for 1 hour
def run_query(query: str) -> pd.DataFrame:
    """Execute a query and return results as a DataFrame."""
    conn = get_snowflake_connection()
    if conn is None:
        return pd.DataFrame()
    
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        columns = [desc[0] for desc in cursor.description]
        data = cursor.fetchall()
        return pd.DataFrame(data, columns=columns)
    except Exception as e:
        st.error(f"Query failed: {e}")
        return pd.DataFrame()


# ============================================
# Data Loading Functions (from pre-computed tables)
# ============================================
@st.cache_data(ttl=3600)
def load_daily_summary():
    return run_query("SELECT * FROM BLUESKY_DB.MAIN.RPT_DAILY_SUMMARY ORDER BY POST_DATE")

@st.cache_data(ttl=3600)
def load_sentiment_by_language():
    return run_query("SELECT * FROM BLUESKY_DB.MAIN.RPT_SENTIMENT_BY_LANGUAGE WHERE TOTAL_POSTS >= 1000 ORDER BY TOTAL_POSTS DESC")

@st.cache_data(ttl=3600)
def load_external_domains(limit=50):
    return run_query(f"SELECT * FROM BLUESKY_DB.MAIN.RPT_EXTERNAL_DOMAINS ORDER BY SHARE_COUNT DESC LIMIT {limit}")

@st.cache_data(ttl=3600)
def load_posting_heatmap():
    return run_query("SELECT * FROM BLUESKY_DB.MAIN.RPT_POSTING_HEATMAP")

@st.cache_data(ttl=3600)
def load_confidence_distribution():
    return run_query("SELECT * FROM BLUESKY_DB.MAIN.RPT_CONFIDENCE_DISTRIBUTION")

@st.cache_data(ttl=3600)
def load_daily_top_ngrams(ngram_type='unigram', limit=20):
    return run_query(f"""
        SELECT * FROM BLUESKY_DB.MAIN.RPT_DAILY_TOP_NGRAMS 
        WHERE NGRAM_TYPE = '{ngram_type}' AND RANK <= {limit}
        ORDER BY POST_DATE DESC, RANK
    """)

@st.cache_data(ttl=3600)
def load_thread_sentiment():
    return run_query("SELECT * FROM BLUESKY_DB.MAIN.RPT_THREAD_SENTIMENT")

@st.cache_data(ttl=3600)
def load_high_confidence_posts(sentiment='Positive', limit=10):
    return run_query(f"""
        SELECT POST_TEXT, SENTIMENT_CONFIDENCE_SCORE, USA_TIMESTAMP 
        FROM BLUESKY_DB.MAIN.RPT_HIGH_CONFIDENCE_POSTS 
        WHERE SENTIMENT_DETECTED_LABEL = '{sentiment}'
        ORDER BY SENTIMENT_CONFIDENCE_SCORE DESC
        LIMIT {limit}
    """)

def load_random_high_confidence_posts(sentiment: str, limit: int, _refresh_key: int = 0):
    """Load random posts with confidence >= 90%. The _refresh_key param busts the cache."""
    return run_query(f"""
        SELECT POST_TEXT, SENTIMENT_CONFIDENCE_SCORE, USA_TIMESTAMP,
               SENTIMENT_DETECTED_LABEL
        FROM BLUESKY_DB.MAIN.FIREHOSE_NLP_LABELED n
        JOIN BLUESKY_DB.MAIN.FIREHOSE_PROCESSED p ON n.CONTENT_ID = p.CONTENT_ID
        WHERE n.SENTIMENT_DETECTED_LABEL = '{sentiment}'
          AND n.SENTIMENT_CONFIDENCE_SCORE >= 0.90
          AND p.POST_TEXT IS NOT NULL
          AND LEN(p.POST_TEXT) > 20
        ORDER BY RANDOM()
        LIMIT {limit}
    """)

@st.cache_data(ttl=3600)
def load_ngram_sentiment(ngram_type='bigram', limit=50):
    return run_query(f"""
        SELECT * FROM BLUESKY_DB.MAIN.RPT_NGRAM_SENTIMENT 
        WHERE NGRAM_TYPE = '{ngram_type}'
        ORDER BY TOTAL_OCCURRENCES DESC
        LIMIT {limit}
    """)

@st.cache_data(ttl=3600)
def search_keyword_sentiment(keyword: str):
    """Search for sentiment of a specific keyword/phrase."""
    return run_query(f"""
        SELECT * FROM BLUESKY_DB.MAIN.RPT_NGRAM_SENTIMENT 
        WHERE LOWER(NGRAM) LIKE '%{keyword.lower()}%'
        ORDER BY TOTAL_OCCURRENCES DESC
        LIMIT 50
    """)


# ============================================
# Sidebar
# ============================================
st.sidebar.title("🦋 Bluesky NLP Analytics")
st.sidebar.markdown("---")

# Navigation
page = st.sidebar.radio(
    "Navigate",
    ["📊 Overview", "📈 Trends", "🗣️ Sentiment", "🔑 Keywords", "🔗 External Links", "💬 Sample Posts"]
)

st.sidebar.markdown("---")
st.sidebar.markdown("""
**About this dashboard**

Analyzes ~18.6M Bluesky posts with NLP 
sentiment analysis using RoBERTa.

Data: May - Nov 2025

Built with Streamlit + Snowflake
""")

# ============================================
# PAGE: Overview
# ============================================
if page == "📊 Overview":
    st.title("🦋 Bluesky NLP Analytics Dashboard")
    st.markdown("Analyzing sentiment and trends across 18.6M Bluesky posts using RoBERTa NLP model.")
    
    # Load data
    daily_data = load_daily_summary()
    lang_data = load_sentiment_by_language()
    
    if daily_data.empty:
        st.warning("⚠️ Unable to load data. Check your Snowflake connection in `.streamlit/secrets.toml`")
        st.stop()
    
    # KPI Cards
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_posts = int(daily_data['TOTAL_POSTS'].sum())
        st.metric("Total Posts", f"{total_posts:,}")
    
    with col2:
        labeled_posts = int(daily_data['LABELED_POSTS'].sum())
        st.metric("Labeled Posts", f"{labeled_posts:,}")
    
    with col3:
        avg_sentiment = daily_data['WEIGHTED_SENTIMENT_SCORE'].mean()
        st.metric("Avg Sentiment", f"{avg_sentiment:.3f}", 
                  delta="Positive" if avg_sentiment > 0 else "Negative")
    
    with col4:
        days_of_data = len(daily_data)
        st.metric("Days of Data", f"{days_of_data}")
    
    st.markdown("---")
    
    # Charts Row 1: Posts Over Time + Sentiment Over Time
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📈 Posts Per Day")
        fig = px.area(
            daily_data, 
            x='POST_DATE', 
            y='TOTAL_POSTS',
            color_discrete_sequence=['#1DA1F2']
        )
        fig.update_layout(xaxis_title="", yaxis_title="Posts", hovermode='x unified')
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("😊 Sentiment Trend")
        fig = px.line(
            daily_data,
            x='POST_DATE',
            y='WEIGHTED_SENTIMENT_SCORE',
            color_discrete_sequence=['#10B981']
        )
        fig.add_hline(y=0, line_dash="dash", line_color="gray")
        fig.update_layout(xaxis_title="", yaxis_title="Weighted Sentiment", hovermode='x unified')
        st.plotly_chart(fig, use_container_width=True)
    
    # Charts Row 2: Sentiment Distribution + By Language
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📊 Overall Sentiment Distribution")
        totals = {
            'Positive': int(daily_data['POSITIVE_COUNT'].sum()),
            'Neutral': int(daily_data['NEUTRAL_COUNT'].sum()),
            'Negative': int(daily_data['NEGATIVE_COUNT'].sum())
        }
        fig = px.pie(
            values=list(totals.values()),
            names=list(totals.keys()),
            color=list(totals.keys()),
            color_discrete_map={'Positive': '#10B981', 'Neutral': '#6B7280', 'Negative': '#EF4444'}
        )
        fig.update_traces(textposition='inside', textinfo='percent+label')
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("🌍 Sentiment by Language (Top 10)")
        top_langs = lang_data.head(10)
        fig = px.bar(
            top_langs,
            x='LANGUAGE',
            y=['POSITIVE_PCT', 'NEUTRAL_PCT', 'NEGATIVE_PCT'],
            barmode='stack',
            color_discrete_map={
                'POSITIVE_PCT': '#10B981', 
                'NEUTRAL_PCT': '#6B7280', 
                'NEGATIVE_PCT': '#EF4444'
            }
        )
        fig.update_layout(xaxis_title="", yaxis_title="Percentage", legend_title="Sentiment")
        st.plotly_chart(fig, use_container_width=True)


# ============================================
# PAGE: Trends
# ============================================
elif page == "📈 Trends":
    st.title("📈 Posting Trends & Patterns")
    
    # Load data
    heatmap_data = load_posting_heatmap()
    
    if heatmap_data.empty:
        st.warning("⚠️ Unable to load heatmap data.")
        st.stop()
    
    # Day of Week x Hour Heatmap
    st.subheader("🗓️ Activity Heatmap (Day of Week × Hour)")
    
    # Pivot for heatmap
    pivot_data = heatmap_data.groupby(['DAY_NAME', 'HOUR_OF_DAY'])['POST_COUNT'].sum().reset_index()
    pivot_table = pivot_data.pivot(index='DAY_NAME', columns='HOUR_OF_DAY', values='POST_COUNT')
    
    # Reorder days
    day_order = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    pivot_table = pivot_table.reindex([d for d in day_order if d in pivot_table.index])
    
    fig = px.imshow(
        pivot_table,
        labels=dict(x="Hour of Day (EST)", y="Day of Week", color="Posts"),
        color_continuous_scale='Blues',
        aspect='auto'
    )
    fig.update_layout(height=400)
    st.plotly_chart(fig, use_container_width=True)
    
    # Monthly Pattern
    st.subheader("📅 Monthly Posting Volume")
    monthly_data = heatmap_data.groupby(['MONTH_NUM', 'MONTH_NAME'])['POST_COUNT'].sum().reset_index()
    monthly_data = monthly_data.sort_values('MONTH_NUM')
    
    fig = px.bar(
        monthly_data,
        x='MONTH_NAME',
        y='POST_COUNT',
        color_discrete_sequence=['#6366F1']
    )
    fig.update_layout(xaxis_title="", yaxis_title="Total Posts")
    st.plotly_chart(fig, use_container_width=True)


# ============================================
# PAGE: Sentiment
# ============================================
elif page == "🗣️ Sentiment":
    st.title("🗣️ Sentiment Analysis Deep Dive")
    
    # Load data
    confidence_data = load_confidence_distribution()
    thread_data = load_thread_sentiment()
    lang_data = load_sentiment_by_language()
    
    # Confidence Distribution
    st.subheader("📊 Model Confidence Distribution")
    st.markdown("How confident is the RoBERTa model in its sentiment predictions?")
    
    if not confidence_data.empty:
        fig = px.bar(
            confidence_data,
            x='CONFIDENCE_BUCKET',
            y='POST_COUNT',
            color='SENTIMENT_DETECTED_LABEL',
            barmode='group',
            color_discrete_map={'Positive': '#10B981', 'Neutral': '#6B7280', 'Negative': '#EF4444'}
        )
        fig.update_layout(
            xaxis_title="Confidence Score",
            yaxis_title="Number of Posts",
            legend_title="Sentiment"
        )
        st.plotly_chart(fig, use_container_width=True)
    
    st.markdown("---")
    
    # Thread Sentiment Analysis
    st.subheader("💬 Reply Thread Sentiment Patterns")
    st.markdown("When someone replies to a post, how does sentiment change?")
    
    if not thread_data.empty:
        col1, col2 = st.columns(2)
        
        with col1:
            # Heatmap of sentiment transitions
            pivot = thread_data.pivot(index='ROOT_SENTIMENT', columns='REPLY_SENTIMENT', values='REPLY_COUNT')
            fig = px.imshow(
                pivot,
                labels=dict(x="Reply Sentiment", y="Original Post Sentiment", color="Count"),
                color_continuous_scale='YlOrRd',
                text_auto=True
            )
            fig.update_layout(height=350)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.dataframe(thread_data, use_container_width=True, height=300)
    
    st.markdown("---")
    
    # Sentiment by Language Table
    st.subheader("🌍 Sentiment by Language (Full Table)")
    if not lang_data.empty:
        st.dataframe(
            lang_data[['LANGUAGE', 'TOTAL_POSTS', 'POSITIVE_PCT', 'NEUTRAL_PCT', 'NEGATIVE_PCT', 'WEIGHTED_SENTIMENT_SCORE']],
            use_container_width=True,
            height=400
        )


# ============================================
# PAGE: Keywords
# ============================================
elif page == "🔑 Keywords":
    st.title("🔑 Keyword & N-gram Analysis")
    
    # Keyword search
    st.subheader("🔍 Search Keyword Sentiment")
    search_term = st.text_input("Enter a keyword or phrase to analyze:", placeholder="e.g., trump, climate, love")
    
    if search_term:
        results = search_keyword_sentiment(search_term)
        if not results.empty:
            st.dataframe(
                results[['NGRAM_TYPE', 'NGRAM', 'TOTAL_OCCURRENCES', 'POSITIVE_PCT', 'NEGATIVE_PCT', 'WEIGHTED_SENTIMENT_SCORE']],
                use_container_width=True
            )
        else:
            st.info("No results found for that keyword.")
    
    st.markdown("---")
    
    # Top N-grams
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📊 Top Unigrams (Single Words)")
        ngram_type = 'unigram'
        unigrams = load_ngram_sentiment(ngram_type, 30)
        if not unigrams.empty:
            fig = px.bar(
                unigrams.head(20).sort_values('TOTAL_OCCURRENCES'),
                x='TOTAL_OCCURRENCES',
                y='NGRAM',
                orientation='h',
                color='WEIGHTED_SENTIMENT_SCORE',
                color_continuous_scale='RdYlGn',
                color_continuous_midpoint=0
            )
            fig.update_layout(yaxis_title="", xaxis_title="Occurrences", height=500)
            st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("📊 Top Bigrams (Two-Word Phrases)")
        bigrams = load_ngram_sentiment('bigram', 30)
        if not bigrams.empty:
            fig = px.bar(
                bigrams.head(20).sort_values('TOTAL_OCCURRENCES'),
                x='TOTAL_OCCURRENCES',
                y='NGRAM',
                orientation='h',
                color='WEIGHTED_SENTIMENT_SCORE',
                color_continuous_scale='RdYlGn',
                color_continuous_midpoint=0
            )
            fig.update_layout(yaxis_title="", xaxis_title="Occurrences", height=500)
            st.plotly_chart(fig, use_container_width=True)
    
    st.markdown("---")
    
    # Trending keywords over time
    st.subheader("📈 Trending Keywords Over Time")
    
    selected_ngram_type = st.selectbox("Select n-gram type:", ['unigram', 'bigram', 'trigram'])
    trending = load_daily_top_ngrams(selected_ngram_type, 10)
    
    if not trending.empty:
        # Get unique top ngrams
        top_ngrams = trending.groupby('NGRAM')['FREQUENCY'].sum().nlargest(10).index.tolist()
        filtered = trending[trending['NGRAM'].isin(top_ngrams)]
        
        fig = px.line(
            filtered,
            x='POST_DATE',
            y='FREQUENCY',
            color='NGRAM',
            title=f"Top 10 {selected_ngram_type}s Over Time"
        )
        fig.update_layout(xaxis_title="", yaxis_title="Daily Frequency", legend_title="Keyword")
        st.plotly_chart(fig, use_container_width=True)


# ============================================
# PAGE: External Links
# ============================================
elif page == "🔗 External Links":
    st.title("🔗 External Link Analysis")
    st.markdown("What websites are Bluesky users sharing most?")
    
    # Load data
    domain_limit = st.slider("Number of domains to show:", 10, 100, 30)
    domains = load_external_domains(domain_limit)
    
    if domains.empty:
        st.warning("⚠️ Unable to load domain data.")
        st.stop()
    
    # Top domains chart
    st.subheader(f"🔝 Top {domain_limit} Shared Domains")
    
    fig = px.bar(
        domains.head(30).sort_values('SHARE_COUNT'),
        x='SHARE_COUNT',
        y='DOMAIN',
        orientation='h',
        color='SHARE_COUNT',
        color_continuous_scale='Viridis'
    )
    fig.update_layout(
        yaxis_title="",
        xaxis_title="Share Count",
        height=600,
        showlegend=False
    )
    st.plotly_chart(fig, use_container_width=True)
    
    # Domain table
    st.subheader("📋 Full Domain Data")
    st.dataframe(
        domains[['DOMAIN', 'SHARE_COUNT', 'UNIQUE_SHARERS', 'FIRST_SHARED', 'LAST_SHARED']],
        use_container_width=True,
        height=400
    )


# ============================================
# PAGE: Sample Posts
# ============================================
elif page == "💬 Sample Posts":
    st.title("💬 High-Confidence Sample Posts")
    st.markdown("Random posts where the model had ≥90% confidence in its sentiment classification.")
    
    # Initialize refresh counter in session state
    if 'sample_refresh_key' not in st.session_state:
        st.session_state.sample_refresh_key = 0
    
    # Refresh button
    col_btn, col_spacer = st.columns([1, 5])
    with col_btn:
        if st.button("🔄 Refresh Samples", type="primary"):
            st.session_state.sample_refresh_key += 1
            st.rerun()
    
    st.markdown("---")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("😊 Random Positive Posts")
        positive_posts = load_random_high_confidence_posts(
            'Positive', 10, st.session_state.sample_refresh_key
        )
        if not positive_posts.empty:
            for _, row in positive_posts.iterrows():
                with st.container():
                    st.markdown(f"**Confidence: {row['SENTIMENT_CONFIDENCE_SCORE']:.1%}**")
                    post_text = row['POST_TEXT'][:500] if len(row['POST_TEXT']) > 500 else row['POST_TEXT']
                    st.markdown(f"> {post_text}")
                    st.caption(f"Posted: {row['USA_TIMESTAMP']}")
                    st.markdown("---")
        else:
            st.info("No posts found.")
    
    with col2:
        st.subheader("😠 Random Negative Posts")
        negative_posts = load_random_high_confidence_posts(
            'Negative', 10, st.session_state.sample_refresh_key
        )
        if not negative_posts.empty:
            for _, row in negative_posts.iterrows():
                with st.container():
                    st.markdown(f"**Confidence: {row['SENTIMENT_CONFIDENCE_SCORE']:.1%}**")
                    post_text = row['POST_TEXT'][:500] if len(row['POST_TEXT']) > 500 else row['POST_TEXT']
                    st.markdown(f"> {post_text}")
                    st.caption(f"Posted: {row['USA_TIMESTAMP']}")
                    st.markdown("---")
        else:
            st.info("No posts found.")


# ============================================
# Footer
# ============================================
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #6B7280; font-size: 0.875rem;'>
    Built by <a href='https://patrick-f-callahan.com' target='_blank'>Patrick F. Callahan</a> | 
    Data: Bluesky Firehose (May-Nov 2025) | 
    NLP Model: <a href='https://huggingface.co/cardiffnlp/twitter-roberta-base-sentiment' target='_blank'>RoBERTa</a>
</div>
""", unsafe_allow_html=True)
