xquery version "3.1";

(:These functions complement the schematron rules created as part of the ODD CEI4Historians schema: https://github.com/virgile-reignier/CEI4Historians/blob/main/cei_for_historians.odd.:)
module namespace cei = "https://github.com/virgile-reignier/CEI4Historians";

declare default element namespace "http://www.tei-c.org/ns/1.0";

(:This function is used to check the uniqueness of the identifiers of the TEI and teiCorpus tags within a collection.:)
declare function cei:findDuplicateIds($collectionName as xs:string) as item()*
{
  let $collection := db:open($collectionName)
  let $teiDocs := $collection//TEI | $collection//teiCorpus
  let $idValues := $teiDocs/@xml:id
  let $duplicates := (
    for $id in distinct-values($idValues)
    where count($idValues[. eq $id]) > 1
    return $id
  )
  where $duplicates
  return (
    "Les identifiants de fichier suivants ne sont pas uniques :",
    for $duplicate in $duplicates
    return $duplicate
)};

(:This function is used to check the consistency of references to the index when these require recurrence.:)
declare function cei:checkInvalidReferences($collectionName as xs:string) as item()*
{
  for $teiDoc in collection($collectionName)//TEI
  let $indexPersons := doc(concat($collectionName, '/index/index_persons.xml'))
  for $elem in ($teiDoc//@active, $teiDoc//@nymRef, $teiDoc//@mutual)
  where contains($elem, ' ')
  let $activeTokens := tokenize($elem, '\s+')
  let $invalidTokens :=
    for $token in $activeTokens
    where empty($indexPersons//*[@xml:id = substring-after($token, '#')])
    return $token
  where exists(($invalidTokens))
  return
    (
      concat("Le document ", $elem/ancestor::TEI/@xml:id/string(), " contient les erreurs suivantes :"),
      concat("dans ", $elem, " :"),
      string-join(($invalidTokens), ", "),
      "ne renvoie vers aucune valeur dans l'index"
    )
};

(:This function ensures that referrals to another act are functional:)
declare function cei:checkInvalidCorresps($collectionName as xs:string) as item()*
{
  let $collection := db:open($collectionName)
let $validIds := $collection//TEI/@xml:id | $collection//teiCorpus/@xml:id | $collection//ref[not(contains(@corresp, '#'))]/@corresp
for $doc in $collection
let $invalidCorresps := $doc//body//*[@corresp and contains(@corresp, '#') and not(substring-after(@corresp, '#') = $validIds)]
for $invalidCorresp in $invalidCorresps
return (
  "L'acte suivant :",
  $invalidCorresp/ancestor::TEI/@xml:id/string(),
  "Contient un renvoi vers un autre acte erroné :",
  $invalidCorresp/@corresp
)
};

declare function cei:executeAllVerifications($collectionName as xs:string) as item()* 
{
  let $result_1 := cei:findDuplicateIds($collectionName)
  let $result_2 := cei:checkInvalidReferences($collectionName)
  let $result_3 := cei:checkInvalidCorresps($collectionName)
  return ($result_1, $result_2, $result_3)
};