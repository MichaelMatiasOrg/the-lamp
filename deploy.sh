#!/bin/bash
# Deploy script for The Lamp
# Usage: ./deploy.sh [staging|production]
#
# ALWAYS runs tests before allowing deployment.

set -e

TARGET="${1:-staging}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqdmVjbXJzZml2bWdmbmlreHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwNDI3MzAsImV4cCI6MjA4NTYxODczMH0.d798KIEaBRqG-nKfhnVtafruYocn99_2VOiUFTRn298}"

echo "🚀 Deploying to: $TARGET"
echo ""

# Determine branch
if [ "$TARGET" = "production" ]; then
    BRANCH="main"
    echo "⚠️  PRODUCTION DEPLOYMENT"
    echo "   This will affect the live system!"
    read -p "   Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
else
    BRANCH="staging"
fi

# Step 1: Run local syntax check
echo ""
echo "📝 Step 1: Checking syntax..."
node --check server-supabase.js || { echo "❌ Syntax error!"; exit 1; }
echo "✓ Syntax OK"

# Step 2: Commit and push
echo ""
echo "📦 Step 2: Pushing to $BRANCH..."
git add -A
git commit -m "Deploy to $TARGET $(date +%Y-%m-%d-%H%M)" --allow-empty
git push origin "$BRANCH"
echo "✓ Pushed"

# Step 3: Wait for Render deploy
echo ""
echo "⏳ Step 3: Waiting 60s for Render to deploy..."
sleep 60

# Step 4: Run integration tests
echo ""
echo "🧪 Step 4: Running integration tests..."
export SUPABASE_ANON_KEY
if node test-supabase.js "$TARGET"; then
    echo ""
    echo "✅ DEPLOYMENT SUCCESSFUL"
    echo "   Target: $TARGET"
    echo "   Branch: $BRANCH"
    echo "   Time: $(date)"
else
    echo ""
    echo "❌ TESTS FAILED!"
    echo "   The deployment may have issues."
    echo "   Check logs and fix before continuing."
    exit 1
fi

# Step 5: For production, also verify data integrity
if [ "$TARGET" = "production" ]; then
    echo ""
    echo "🔍 Step 5: Production data integrity check..."
    TASK_COUNT=$(curl -s "https://yjvecmrsfivmgfnikxsc.supabase.co/rest/v1/tasks?select=id" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
        -H "Prefer: count=exact" -I 2>/dev/null | grep -i content-range | grep -oE '[0-9]+$')
    echo "   Tasks in Supabase: $TASK_COUNT"
    
    if [ "$TASK_COUNT" -lt 50 ]; then
        echo "⚠️  WARNING: Task count seems low. Verify data integrity!"
    else
        echo "✓ Data looks healthy"
    fi
fi

echo ""
echo "🎉 Done!"
