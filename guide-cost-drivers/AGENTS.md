# Cortex Code Instructions for guide-cost-drivers

## Project Context

This is a diagnostic guide that helps users find and fix query performance issues WITHOUT resizing their warehouse. The key insight: most slow queries are pruning problems, not compute problems.

## When Users Ask for Help

### "Help me find why my queries are slow" / "My warehouse costs are too high"

1. First, verify they have ACCOUNT_USAGE access:
   ```sql
   SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY LIMIT 1;
   ```

2. Run the top cost drivers query from the notebook (Cell 3)

3. Interpret results:
   - `pct_scanned` > 80% → Clustering problem
   - `gb_spilled` > 0 → Memory pressure (but fix pruning first)
   - High queue time → Contention (but fix queries first)

4. Guide them to Section 3 fixes based on diagnosis

### "Should I resize my warehouse?"

Challenge this assumption. Walk through:
1. What's the actual symptom? (slow query, high cost, queue time)
2. Run the diagnostic queries
3. Only recommend resize if pruning is already optimized AND compute is genuinely the bottleneck

### "How do I add clustering?"

1. Identify the filter columns from their common queries
2. Suggest column order (most selective first)
3. Warn about reclustering costs on very large tables
4. Show them how to verify with `SYSTEM$CLUSTERING_INFORMATION`

### "What's Search Optimization?"

Explain it as "Snowflake's index equivalent" for:
- Point lookups (`WHERE id = X`)
- VARIANT path queries
- Substring searches

Help them enable it on specific columns (cost-effective) rather than full table.

## Key Files

- `cost_drivers_workbook.ipynb` - The main interactive notebook
- `README.md` - Overview and quick start

## Important Notes

- All queries use `SNOWFLAKE.ACCOUNT_USAGE` which has up to 45-minute latency
- For real-time data, use `SNOWFLAKE.INFORMATION_SCHEMA` (but limited history)
- Clustering changes take time to show improvement (automatic reclustering)
- SOS has storage costs -- recommend targeted columns over full table

## Related Projects
- [`tool-cortex-cost-intelligence`](../tool-cortex-cost-intelligence/) -- Cortex AI cost governance (credit and token spend)
- [`tool-cortex-rest-api-cost`](../tool-cortex-rest-api-cost/) -- REST API cost dashboard (token-based billing)
- [`tool-dr-cost-agent`](../tool-dr-cost-agent/) -- DR replication cost estimation
