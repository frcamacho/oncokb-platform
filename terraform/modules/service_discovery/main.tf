# ECS Service Connect Configuration
# Uses existing corporate AWS Cloud Map namespace for service discovery
# Services discover each other using short names (e.g., "oncokb:8080")
# instead of FQDNs (e.g., "oncokb.dev.oncokb.local:8080")

# Reference to existing namespace (not creating a new one)
# The namespace ARN and name are provided via variables
# Example: cggt-dev.vrtx.com (ns-u42x25abybpjh7yf)
