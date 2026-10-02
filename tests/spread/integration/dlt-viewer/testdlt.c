#include <dlt/dlt.h>
#include <unistd.h>

DLT_DECLARE_CONTEXT(ctx);

int main(void)
{
    /* Register application */
    DLT_REGISTER_APP("TAPP", "Test Application");

    /* Register context (3 arguments!) */
    DLT_REGISTER_CONTEXT(ctx, "TCTX", "Test Context");

    /* Emit some logs */
    for (int i = 0; i < 5; i++) {
        DLT_LOG(ctx, DLT_LOG_INFO, DLT_STRING("Hello from test"));
        sleep(1);
    }

    /* Cleanup */
    DLT_UNREGISTER_CONTEXT(ctx);
    DLT_UNREGISTER_APP();

    return 0;
}

