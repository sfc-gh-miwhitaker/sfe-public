"""
Snowflake ML Lifecycle — reference pipeline (illustrative, not deployed by this guide)
Pair-programmed by SE Community + Cortex Code

Walks one model through: Feature Store -> ML Job training -> Model Registry ->
warehouse batch scoring -> optional SPCS REST service -> Task-graph retraining.

Requires a recent snowflake-ml-python (2.0.0+; pin it) and snowflake.core.
For large or unstructured batch scoring, swap step 3's mv.run() for mv.run_batch().
Placeholders: ML_DB.ML, ML_WH, ML_CPU_POOL (CPU_X64_S), ML_DB.RAW.CUSTOMER_EVENTS.
"""
from datetime import timedelta

from snowflake.core import CreateMode, Root
from snowflake.core.task.dagv1 import DAG, DAGOperation, DAGTask
from snowflake.ml.feature_store import Entity, FeatureStore, FeatureView, CreationMode
from snowflake.ml.jobs import remote
from snowflake.ml.model import task
from snowflake.ml.registry import Registry
from snowflake.snowpark import Session

session = Session.builder.getOrCreate()
session.sql("ALTER SESSION SET QUERY_TAG = 'ml:reference_pipeline'").collect()

DB, SCHEMA, WH, POOL = "ML_DB", "ML", "ML_WH", "ML_CPU_POOL"

# --- 1. Feature Store: entity + managed feature view (dynamic-table backed) -------------
fs = FeatureStore(session, database=DB, name=SCHEMA, default_warehouse=WH,
                  creation_mode=CreationMode.CREATE_IF_NOT_EXIST)
customer = Entity(name="CUSTOMER", join_keys=["CUSTOMER_ID"])
fs.register_entity(customer)

features_df = session.sql("""
    SELECT customer_id, event_ts,
           tenure_months, monthly_charges, support_tickets, region
    FROM ML_DB.RAW.CUSTOMER_EVENTS
""")
fv = FeatureView(name="CUSTOMER_FEATURES", entities=[customer], feature_df=features_df,
                 timestamp_col="EVENT_TS", refresh_freq="1 day")
fv = fs.register_feature_view(fv, version="V1", overwrite=True)


# --- 2. Training as an ML Job on a CPU compute pool ------------------------------------
@remote(POOL, stage_name="ML_DB.ML.JOB_STAGE", database=DB, schema=SCHEMA)
def train() -> None:
    # No arguments: task-graph tasks can't pass them. Constants live inside the job payload.
    from datetime import datetime, timezone
    from sklearn.ensemble import HistGradientBoostingClassifier
    from sklearn.metrics import roc_auc_score
    from snowflake.ml.feature_store import FeatureStore
    from snowflake.ml.registry import Registry
    from snowflake.snowpark import Session

    DB, SCHEMA, WH = "ML_DB", "ML", "ML_WH"
    model_version = "V" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
    s = Session.builder.getOrCreate()
    store = FeatureStore(s, database=DB, name=SCHEMA, default_warehouse=WH)
    spine = s.table("ML_DB.ML.CHURN_LABELS")  # CUSTOMER_ID, LABEL_TS, CHURNED
    ds = store.generate_dataset(
        name="CHURN_TRAINING", version=model_version, spine_df=spine,
        features=[store.get_feature_view("CUSTOMER_FEATURES", "V1")],
        spine_timestamp_col="LABEL_TS", spine_label_cols=["CHURNED"])
    pdf = ds.read.to_pandas()
    cols = ["TENURE_MONTHS", "MONTHLY_CHARGES", "SUPPORT_TICKETS"]
    x = pdf[cols]
    y = pdf["CHURNED"]

    clf = HistGradientBoostingClassifier().fit(x, y)
    auc = roc_auc_score(y, clf.predict_proba(x)[:, 1])  # replace with a held-out split

    Registry(s, database_name=DB, schema_name=SCHEMA).log_model(
        clf, model_name="CHURN_MODEL", version_name=model_version,
        # Snowpark sample drawn from the Dataset -> Dataset-to-model lineage is captured.
        # A pandas frame here would record no lineage.
        sample_input_data=ds.read.to_snowpark_dataframe().select(cols).limit(100),
        metrics={"train_roc_auc": float(auc)},
        target_platforms=["WAREHOUSE", "SNOWPARK_CONTAINER_SERVICES"],
        task=task.Task.TABULAR_BINARY_CLASSIFICATION)  # required for ML Observability
    # New versions are logged but not promoted. Promote after evaluation with
    # ALTER MODEL ML_DB.ML.CHURN_MODEL SET DEFAULT_VERSION = '<version>' (or an alias).


if __name__ == "__main__":
    train().result()  # first training run, submitted as an ML Job

    # --- 3. Batch scoring in a warehouse (mv.run) --------------------------------------
    mv = Registry(session, database_name=DB, schema_name=SCHEMA).get_model("CHURN_MODEL").default  # promoted version only
    scored = mv.run(session.table("ML_DB.ML.CUSTOMERS_TO_SCORE"), function_name="predict_proba")
    scored.write.save_as_table("ML_DB.ML.CHURN_SCORES", mode="overwrite")

    # --- 4. Optional real-time REST service on SPCS --------------------------------------
    # min_instances=0 lets the SERVICE suspend after 30 min idle; the POOL still bills
    # until its own AUTO_SUSPEND_SECS elapses. Budget for cold start on first request.
    mv.create_service(service_name="CHURN_SERVICE", service_compute_pool=POOL,
                      ingress_enabled=True, min_instances=0, max_instances=2)

    # --- 5. Weekly retraining as a task graph -------------------------------------------
    with DAG("CHURN_RETRAIN_DAG", schedule=timedelta(days=7), warehouse=WH,
             stage_location="@ML_DB.ML.JOB_STAGE") as dag:
        refresh = DAGTask("REFRESH_FEATURES",
                          definition="ALTER DYNAMIC TABLE ML_DB.ML.\"CUSTOMER_FEATURES$V1\" REFRESH")
        retrain = DAGTask("RETRAIN", definition=train)  # @remote task: no warehouse
        refresh >> retrain

    schema = Root(session).databases[DB].schemas[SCHEMA]
    DAGOperation(schema).deploy(dag, mode=CreateMode.or_replace)
