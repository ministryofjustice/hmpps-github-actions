#!node

import fs from 'fs'

const directoryExists = (dir) => fs.existsSync(dir) && fs.statSync(dir).isDirectory()

const createIfDoesNotExist = (dir) => {
    if(!directoryExists(dir)) fs.mkdirSync(dir, { recursive: true})
}

const repo = process.argv[2]

if (!directoryExists(repo)) {
    throw Error(`'${repo}' should be an existing directory`)
}

const destActions = `${repo}/.github/actions`
const destScripts = `${repo}/.github/scripts`

createIfDoesNotExist(destActions)
createIfDoesNotExist(destScripts)

fs.cpSync('templates/scripts', destScripts, { recursive: true})

fs.readdirSync('templates').forEach(file => {
    if (file.endsWith('yml')){
        fs.cpSync(`templates/${file}`, `${destActions}/${file}`)
    }
})
