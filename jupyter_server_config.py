import os
import sys

level="INFO"
if os.getenv("DEBUG"):
    level="DEBUG"

c.ServerApp.logging_config = {
    'handlers': {
        'stdout': {
            'class': 'logging.StreamHandler',
            'level': level,
            'stream': 'ext://sys.stdout'
        },
        'console': {
            'level': 'WARN',
        }
    },
    'loggers': {
        'console': {
            'handlers': [ 'console', 'stdout' ],
        }
    }
}
