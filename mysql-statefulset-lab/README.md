# MySQL on Kubernetes: Manual Setup Lab

This lab demonstrates how to deploy a production-ready MySQL database cluster using only core Kubernetes resources—no operators or custom controllers. You'll use StatefulSets, Services, ConfigMaps, Secrets, and PersistentVolumeClaims to build a resilient, scalable MySQL setup.

## Learning Objectives
- Understand the manual steps required to run MySQL on Kubernetes
- Contrast with operator-based solutions (e.g., Percona, CloudNativePG)
- Learn about StatefulSets, persistent storage, and basic configuration management

## Lab Steps

1. **Create a Secret for MySQL root password**
2. **Create a ConfigMap for MySQL configuration**
3. **Deploy a headless Service for stable network identity**
4. **Deploy a StatefulSet for MySQL pods with persistent storage**
5. **(Optional) Deploy a MySQL client pod for testing**

## Files
- `mysql-secret.yaml`: Secret for root password
- `mysql-configmap.yaml`: ConfigMap for MySQL config
- `mysql-service.yaml`: Headless Service for MySQL
- `mysql-statefulset.yaml`: StatefulSet for MySQL
- `mysql-client.yaml`: MySQL client pod (optional)

## Notes
- This setup is fully manual and requires you to manage upgrades, backups, and failover yourself.
- For production, consider using operators for automated management.

---

## 1. Create a Secret for MySQL root password
```yaml
# mysql-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-root-password
  labels:
    app: mysql
stringData:
  MYSQL_ROOT_PASSWORD: my-secret-pw
```
Apply with:
```sh
kubectl apply -f mysql-secret.yaml
```

## 2. Create a ConfigMap for MySQL configuration
```yaml
# mysql-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  labels:
    app: mysql
  
data:
  my.cnf: |
    [mysqld]
    server-id=1
    log-bin=mysql-bin
    # Add more config as needed
```
Apply with:
```sh
kubectl apply -f mysql-configmap.yaml
```

## 3. Create a Headless Service
```yaml
# mysql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  ports:
    - port: 3306
      name: mysql
  clusterIP: None
  selector:
    app: mysql
```
Apply with:
```sh
kubectl apply -f mysql-service.yaml
```

## 4. Deploy a StatefulSet for MySQL
```yaml
# mysql-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-root-password
              key: MYSQL_ROOT_PASSWORD
        volumeMounts:
        - name: config
          mountPath: /etc/mysql/conf.d
        - name: data
          mountPath: /var/lib/mysql
      volumes:
      - name: config
        configMap:
          name: mysql-config
          items:
          - key: my.cnf
            path: my.cnf
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```
Apply with:
```sh
kubectl apply -f mysql-statefulset.yaml
```

## 5. Deploy a MySQL client pod

### Using Secret and ConfigMap for Connection

We'll update the client pod to use the MySQL root password from the Secret and connection parameters from a ConfigMap. The pod will start with a shell so you can run the MySQL client interactively.

**mysql-client-configmap.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-client-config
data:
  MYSQL_HOST: "mysql-0.mysql"
  MYSQL_USER: "root"
```

**mysql-client.yaml**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql-client
spec:
  containers:
  - name: mysql-client
    image: mysql:8.0
    command: ["sleep", "3600"]
    env:
    - name: MYSQL_HOST
      valueFrom:
        configMapKeyRef:
          name: mysql-client-config
          key: MYSQL_HOST
    - name: MYSQL_USER
      valueFrom:
        configMapKeyRef:
          name: mysql-client-config
          key: MYSQL_USER
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysql-root-password
          key: MYSQL_ROOT_PASSWORD
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

Apply with:
```sh
kubectl apply -f mysql-client-configmap.yaml
kubectl apply -f mysql-client.yaml
```
### Initialize the Database with Sample Data

To create the test database and populate the `cars` table with sample data:

3. Copy the sql script to the pod and install :
  ```sh
  kubectl cp mysql-init-cars.sql mysql-client:/tmp/mysql-init-cars.sql
  kubectl exec -it mysql-client -- bash
  mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASSWORD" < /tmp/mysql-init-cars.sql
  ```

This will create the `testdb` database, the `cars` table, and insert sample records.

To connect to MySQL from inside the client pod:

```sh
kubectl exec -it mysql-client -- bash

mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASSWORD"

```


---

## Cleanup
```sh
kubectl delete -f mysql-client.yaml
kubectl delete -f mysql-statefulset.yaml
kubectl delete -f mysql-service.yaml
kubectl delete -f mysql-configmap.yaml
kubectl delete -f mysql-secret.yaml
```

## Discussion
- What are the limitations of this approach?
- How would you handle backups, upgrades, and failover?
- Compare with operator-based solutions.
