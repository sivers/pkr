package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	_ "github.com/lib/pq"
)

type Thing map[string]interface{}

//String convert interface thing value to string
func (t Thing) String(key string) string {
	v, ok := t[key]
	if !ok {
		return ""
	}

	s, ok := v.(string)
	if !ok {
		return ""
	}

	return s
}

//Bool convert interface thing value to boolean
func (t Thing) Bool(key string) bool {
	v, ok := t[key]
	if !ok {
		return false
	}
	b, ok := v.(bool)
	if !ok {
		return false
	}
	return b
}

//Things represent things collection array
type Things []Thing

//connectDb db connection
func connectDb() (*sql.DB, error) {
	db, err := sql.Open("postgres", "dbname=pkr user=pkr sslmode=disable")
	if err != nil {
		return nil, err
	}

	return db, nil
}

//DbQueryRow represent sql.QueryRow method interface to support commit/rollback method
type DbQueryRow interface {
	QueryRow(query string, args ...interface{}) *sql.Row
}

func qa(db DbQueryRow, pgfunc string, args ...interface{}) (bool, []byte) {
	var argString []string
	for i, _ := range args {
		argString = append(argString, fmt.Sprintf("$%d", i+1))
	}

	sqlStatement := fmt.Sprintf("SELECT ok, js from %s(%s)", pgfunc, strings.Join(argString, ","))
	var ok sql.NullBool
	var js []byte

	err := db.QueryRow(sqlStatement, args...).Scan(&ok, &js)
	if err != nil {
		log.Println("failed to execute sql:", err.Error())
		return false, nil
	}

	return ok.Bool, js
}

func main() {
	//example

	//create db connection
	db, err := connectDb()
	if err != nil {
		panic(err)
	}
	//try to ping db. exit when error
	if err := db.Ping(); err != nil {
		panic(err)
	}

	//close connection at last
	defer db.Close()

	//pull data from things pg function
	ok, js := qa(db, "things")
	//convert to Things = array of Thing
	var things Things
	err = json.Unmarshal(js, &things)
	if err != nil {
		log.Println("unable to decode to Things struct", err)
		return
	}
	fmt.Println("ok:", ok)
	fmt.Println("things[0][name]", things[0].String("name"))

	//pull data from thing_get pg func with one parameter
	ok, js = qa(db, "thing_get", 1)
	var thing Thing
	err = json.Unmarshal(js, &thing)
	if err != nil {
		log.Println("unable to decode to Things struct", err)
		return
	}
	fmt.Println("ok:", ok)
	fmt.Println("thing.category", thing.String("category"))

}
