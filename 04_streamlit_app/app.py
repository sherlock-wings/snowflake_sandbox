"""
Bluesky Analytics Dashboard
A Streamlit application for exploring Bluesky social media data.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta

# ============================================
# Page Configuration
# ============================================
st.set_page_config(
    page_title="Bluesky Analytics",
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
    
    Add your credentials in .streamlit/secrets.toml (local) or
    Streamlit Cloud's Secrets Management (production).
    """
    try:
        import snowflake.connector
        
        conn = snowflake.connector.connect(
            user=st.secrets["snowflake"]["user"],
            password=st.secrets["snowflake"]["password"],
            account=st.secrets["snowflake"]["account"],
            warehouse=st.secrets["snowflake"]["warehouse"],
            database=st.secrets["snowflake"]["database"],
            schema=st.secrets["snowflake"]["schema"],
        )
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
# Demo Data (for development/preview)
# ============================================
def get_demo_data():
    """Generate sample data for demo purposes."""
    import numpy as np
    
    # Generate date range
    dates = pd.date_range(start='2025-01-01', end='2026-02-18', freq='D')
    
    # Posts over time
    posts_data = pd.DataFrame({
        'date': dates,
        'posts': np.random.poisson(500, len(dates)) + np.linspace(100, 300, len(dates)).astype(int),
        'unique_users': np.random.poisson(150, len(dates)) + np.linspace(50, 150, len(dates)).astype(int),
    })
    
    # Top hashtags
    hashtags_data = pd.DataFrame({
        'hashtag': ['#tech', '#python', '#dataengineering', '#bluesky', '#ai', 
                   '#datascience', '#coding', '#opensource', '#devops', '#analytics'],
        'count': [15234, 12456, 9876, 8765, 7654, 6543, 5432, 4321, 3210, 2109]
    })
    
    # Engagement by hour
    hours = list(range(24))
    engagement_data = pd.DataFrame({
        'hour': hours,
        'avg_likes': [10 + 30 * np.sin((h - 6) * np.pi / 12) + np.random.normal(0, 5) for h in hours],
        'avg_reposts': [5 + 15 * np.sin((h - 6) * np.pi / 12) + np.random.normal(0, 2) for h in hours],
    })
    engagement_data['avg_likes'] = engagement_data['avg_likes'].clip(lower=0)
    engagement_data['avg_reposts'] = engagement_data['avg_reposts'].clip(lower=0)
    
    # User growth
    user_growth = pd.DataFrame({
        'date': dates,
        'cumulative_users': np.cumsum(np.random.poisson(50, len(dates))) + 10000
    })
    
    return {
        'posts': posts_data,
        'hashtags': hashtags_data,
        'engagement': engagement_data,
        'user_growth': user_growth
    }


# ============================================
# Sidebar
# ============================================
st.sidebar.title("🦋 Bluesky Analytics")
st.sidebar.markdown("---")

# Data source toggle
use_demo = st.sidebar.checkbox("Use Demo Data", value=True, 
                                help="Toggle off to use live Snowflake data")

# Date range filter
st.sidebar.subheader("Filters")
date_range = st.sidebar.date_input(
    "Date Range",
    value=(datetime.now() - timedelta(days=30), datetime.now()),
    max_value=datetime.now()
)

st.sidebar.markdown("---")
st.sidebar.markdown("""
**About this dashboard**

This dashboard analyzes Bluesky social media data 
stored in Snowflake. Built with Streamlit.

[View Source Code](https://github.com/patrickfcallahan/bluesky-analytics)
""")


# ============================================
# Main Dashboard
# ============================================
st.title("🦋 Bluesky Analytics Dashboard")
st.markdown("Exploring trends and engagement patterns on the Bluesky social network.")

# Load data
if use_demo:
    data = get_demo_data()
    st.info("📊 Showing demo data. Uncheck 'Use Demo Data' in the sidebar to connect to Snowflake.")
else:
    # Replace these with your actual queries
    st.warning("⚠️ Configure your Snowflake connection in `.streamlit/secrets.toml`")
    data = get_demo_data()  # Fallback to demo

# ============================================
# KPI Cards
# ============================================
col1, col2, col3, col4 = st.columns(4)

with col1:
    total_posts = data['posts']['posts'].sum()
    st.metric("Total Posts", f"{total_posts:,}")

with col2:
    avg_daily_posts = data['posts']['posts'].mean()
    st.metric("Avg Daily Posts", f"{avg_daily_posts:,.0f}")

with col3:
    unique_users = data['posts']['unique_users'].sum()
    st.metric("Unique Posters", f"{unique_users:,}")

with col4:
    latest_users = data['user_growth']['cumulative_users'].iloc[-1]
    st.metric("Total Users", f"{latest_users:,}")

st.markdown("---")

# ============================================
# Charts Row 1
# ============================================
col1, col2 = st.columns(2)

with col1:
    st.subheader("📈 Posts Over Time")
    fig = px.area(
        data['posts'], 
        x='date', 
        y='posts',
        color_discrete_sequence=['#1DA1F2']
    )
    fig.update_layout(
        xaxis_title="",
        yaxis_title="Posts",
        hovermode='x unified',
        showlegend=False
    )
    st.plotly_chart(fig, use_container_width=True)

with col2:
    st.subheader("👥 User Growth")
    fig = px.line(
        data['user_growth'],
        x='date',
        y='cumulative_users',
        color_discrete_sequence=['#6366F1']
    )
    fig.update_layout(
        xaxis_title="",
        yaxis_title="Cumulative Users",
        hovermode='x unified'
    )
    st.plotly_chart(fig, use_container_width=True)

# ============================================
# Charts Row 2
# ============================================
col1, col2 = st.columns(2)

with col1:
    st.subheader("#️⃣ Top Hashtags")
    fig = px.bar(
        data['hashtags'].sort_values('count', ascending=True),
        x='count',
        y='hashtag',
        orientation='h',
        color='count',
        color_continuous_scale='Blues'
    )
    fig.update_layout(
        xaxis_title="Usage Count",
        yaxis_title="",
        showlegend=False,
        coloraxis_showscale=False
    )
    st.plotly_chart(fig, use_container_width=True)

with col2:
    st.subheader("⏰ Engagement by Hour")
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=data['engagement']['hour'],
        y=data['engagement']['avg_likes'],
        name='Avg Likes',
        mode='lines+markers',
        line=dict(color='#10B981', width=2)
    ))
    fig.add_trace(go.Scatter(
        x=data['engagement']['hour'],
        y=data['engagement']['avg_reposts'],
        name='Avg Reposts',
        mode='lines+markers',
        line=dict(color='#F59E0B', width=2)
    ))
    fig.update_layout(
        xaxis_title="Hour of Day (UTC)",
        yaxis_title="Average Count",
        hovermode='x unified',
        legend=dict(orientation='h', yanchor='bottom', y=1.02)
    )
    st.plotly_chart(fig, use_container_width=True)

# ============================================
# Data Table
# ============================================
st.markdown("---")
st.subheader("📋 Raw Data Preview")

tab1, tab2 = st.tabs(["Daily Posts", "Hashtags"])

with tab1:
    st.dataframe(
        data['posts'].sort_values('date', ascending=False).head(30),
        use_container_width=True
    )

with tab2:
    st.dataframe(
        data['hashtags'].sort_values('count', ascending=False),
        use_container_width=True
    )

# ============================================
# Footer
# ============================================
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #6B7280; font-size: 0.875rem;'>
    Built by <a href='https://patrick-f-callahan.com' target='_blank'>Patrick F. Callahan</a> | 
    <a href='https://github.com/patrickfcallahan/bluesky-analytics' target='_blank'>Source Code</a>
</div>
""", unsafe_allow_html=True)
