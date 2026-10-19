# Źródła danych

## Miejsca chłodu (APP-05)

Plik: `assets/demo/places_cool.json` (kontrakt `/v1/places`), quest: `assets/demo/quest.json`.

> **Przed demo trzeba ponownie sprawdzić godziny otwarcia.** Dane zebrano 2026-10-19, czyli poza sezonem letnim. Tam, gdzie miejsce nie publikuje osobnych godzin letnich, w `hours` są godziny bieżące (zaznaczone w uwagach).

Zasady:

- Współrzędne: OpenStreetMap / Nominatim (punkt budynku; dla parków punkt środkowy parku, dla Ogrodu Botanicznego adres kasy przy ul. Krzemienieckiej). Kody pocztowe: ze strony miejsca, a jeśli strona ich nie podaje, z OSM.
- `hours: null` = otwarte całą dobę, `[]` = nieczynne w danym dniu.
- `amenities` i `accessible` wpisane tylko wtedy, gdy potwierdza je źródło (strona miejsca, deklaracja dostępności) albo są oczywiste (toalety i klimatyzacja w centrum handlowym). `accessible: false` oznacza „brak potwierdzenia”, a nie „niedostępne”.
- Punkty wody pitnej (`water`) nie zostały przypisane żadnemu miejscu: nie znaleziono źródła, które by je potwierdzało.

| id | Miejsce | Źródło godzin | Sprawdzono | Uwagi |
| --- | --- | --- | --- | --- |
| cool-001 | EC1 Łódź – Miasto Kultury | [ec1lodz.pl/ckini/informacje-praktyczne](https://ec1lodz.pl/ckini/informacje-praktyczne) | 2026-10-19 | Godziny Centrum Komiksu (wt–nd 10:00–18:00), jedyne godziny podane na stronie bez JavaScriptu. Godziny Centrum Nauki i Techniki i Planetarium mogą być inne. Brak osobnych godzin letnich. Wejścia bezprogowe, drzwi automatyczne. |
| cool-002 | Manufaktura | [manufaktura.com/godziny-otwarcia/obiekt](https://manufaktura.com/godziny-otwarcia/obiekt) | 2026-10-19 | Galeria handlowa pn–sob 10:00–22:00. W niedziele niehandlowe galeria jest zamknięta, czynne jest Qulinarium (12:00–20:00), i te godziny wpisano na niedzielę. Toalety dla osób z niepełnosprawnościami: [dostępność](https://manufaktura.com/site/613/dostepnosc-w-manufakturze). |
| cool-003 | Galeria Łódzka | [galeria-lodzka.pl/o-centrum/godziny-otwarcia](https://www.galeria-lodzka.pl/o-centrum/godziny-otwarcia/) | 2026-10-19 | Pn–sob 9:30–21:00. W niedzielę wpisano „nieczynne”; strona podaje 10:00–20:00, co dotyczy tylko niedziel handlowych. |
| cool-004 | Port Łódź | [portlodz.pl/pl/godziny-otwarcia](https://portlodz.pl/pl/godziny-otwarcia) | 2026-10-19 | Pn–sob 10:00–21:00 (dane strukturalne strony). W niedziele niehandlowe centrum jest nieczynne, w handlowe 10:00–20:00. |
| cool-005 | Dworzec Łódź Fabryczna | [plk-sa.pl/…/dworzec-lodz-fabryczna/o-dworcu](https://www.plk-sa.pl/informacje/dworce/dworzec-lodz-fabryczna/o-dworcu) | 2026-10-19 | Dworzec czynny całodobowo. Toalety płatne (czynne całą dobę, dostosowane), 10 wind. |
| cool-006 | Mediateka MeMo (filia nr 29) | [biblioteka.lodz.pl/filie/filia-nr-29-mediateka-memo](https://www.biblioteka.lodz.pl/filie/filia-nr-29-mediateka-memo/) | 2026-10-19 | Godziny bieżące; w lipcu i sierpniu filie mogą mieć skrócone godziny. Winda i toalety dostosowane wg [deklaracji dostępności](https://www.biblioteka.lodz.pl/deklaracja-dostepnosci/). |
| cool-007 | Biblioteka Wolność (filia nr 39) | [biblioteka.lodz.pl/filie/filia-nr-39-biblioteka-wolnosc](https://www.biblioteka.lodz.pl/filie/filia-nr-39-biblioteka-wolnosc/) | 2026-10-19 | Godziny bieżące; w wakacje mogą być inne. Parter, toaleta dostosowana wg deklaracji dostępności. |
| cool-008 | Wojewódzka Biblioteka Publiczna | [nowa.wbp.lodz.pl/godziny-otwarcia](https://nowa.wbp.lodz.pl/godziny-otwarcia/) | 2026-10-19 | Godziny bieżące (pn–pt 8:00–19:45, sob 8:00–15:00); brak informacji o godzinach letnich. Wejście dla wózków, winda i toaleta na parterze wg [deklaracji dostępności](https://nowa.wbp.lodz.pl/deklaracja-dostepnosci/). |
| cool-009 | Muzeum Sztuki ms¹ | [msl.org.pl/godziny-otwarcia-1](https://msl.org.pl/godziny-otwarcia-1) | 2026-10-19 | Brak osobnych godzin letnich. Dostępność nie potwierdzona na stronie, stąd `accessible: false`. |
| cool-010 | Muzeum Sztuki ms² | [msl.org.pl/godziny-otwarcia-1](https://msl.org.pl/godziny-otwarcia-1) | 2026-10-19 | Jak ms¹. |
| cool-011 | Muzeum Miasta Łodzi | [muzeum-lodz.pl/palac-rodziny-poznanskich-zaplanuj-wizyte](https://muzeum-lodz.pl/palac-rodziny-poznanskich-zaplanuj-wizyte/) | 2026-10-19 | Brak osobnych godzin letnich. Platforma schodowa przy wejściu od ul. Zachodniej (z pomocą obsługi), toaleta „Komfortka”. Pałac zamknięty 27–31.10.2026. |
| cool-012 | Centralne Muzeum Włókiennictwa | [cmwl.pl/public/informacje/godziny-otwarcia](https://cmwl.pl/public/informacje/godziny-otwarcia) | 2026-10-19 | Brak osobnych godzin letnich. Dostępność nie potwierdzona. |
| cool-013 | Muzeum Kinematografii | [muzeumkinematografii.pl/wizyta/zaplanuj-wizyte](https://muzeumkinematografii.pl/wizyta/zaplanuj-wizyte/) | 2026-10-19 | Brak osobnych godzin letnich. Windy i 3 toalety dostosowane wg [strony o dostępności](https://muzeumkinematografii.pl/wizyta/muzeum-dostepne/). |
| cool-014 | Palmiarnia Łódź | [botaniczny.lodz.pl/palmiarnia/godziny-otwarcia](https://www.botaniczny.lodz.pl/palmiarnia/godziny-otwarcia/) | 2026-10-19 | Godziny sezonu kwiecień–wrzesień (wt–nd 10:00–18:00). Szklarnia z roślinami tropikalnymi, latem bywa w niej ciepło i wilgotno; chłód daje otaczający park Źródliska. |
| cool-015 | Park Źródliska I | [zzm.lodz.pl/…/parki-i-zielence](https://zzm.lodz.pl/zarzad-zieleni-miejskiej/zielen/parki-i-zielence/) | 2026-10-19 | ZZM nie podaje godzin; park jest ogrodzony, więc trzeba sprawdzić, czy bramy są zamykane na noc. Staw i zbiorniki wodne. |
| cool-016 | Park im. H. Sienkiewicza | jw. | 2026-10-19 | Godziny nie podane; fontanna. |
| cool-017 | Park im. S. Staszica | jw. | 2026-10-19 | Godziny nie podane; staw. Niskie ogrodzenie. |
| cool-018 | Park im. ks. J. Poniatowskiego | jw. | 2026-10-19 | Godziny nie podane; staw, fontanna posadzkowa, automatyczna toaleta dostosowana dla osób z niepełnosprawnościami. |
| cool-019 | Park Helenów | jw. | 2026-10-19 | Godziny nie podane; stawy. |
| cool-020 | Ogród Botaniczny w Łodzi | [botaniczny.lodz.pl/ogrod-botaniczny/godziny-otwarcia](https://www.botaniczny.lodz.pl/ogrod-botaniczny/godziny-otwarcia/) | 2026-10-19 | Godziny sezonu maj–sierpień (codziennie 9:00–20:00); w październiku 9:00–17:00, od 1 listopada do 31 marca nieczynny. Wstęp płatny. |

### Quest „Chłodne hasło”

Hasło **CHŁODNO**. 7 miejsc tworzy pieszą trasę przez Śródmieście (5 km w linii prostej, ok. 6 km pieszo) od Manufaktury do Galerii Łódzkiej. Kod QR wisi przy ogólnodostępnym wejściu.

| Kolejność | Litera | id | Miejsce |
| --- | --- | --- | --- |
| 1 | C | cool-002 | Manufaktura |
| 2 | H | cool-007 | Biblioteka Wolność (pl. Wolności 4) |
| 3 | Ł | cool-006 | Mediateka MeMo (ul. Moniuszki 5) |
| 4 | O | cool-017 | Park im. S. Staszica |
| 5 | D | cool-005 | Dworzec Łódź Fabryczna |
| 6 | N | cool-001 | EC1 Łódź – Miasto Kultury |
| 7 | O | cool-003 | Galeria Łódzka |

W poniedziałki nieczynne są MeMo i EC1, w niedziele Biblioteka Wolność i (w niedziele niehandlowe) Galeria Łódzka. Quest nie wymaga zebrania liter jednego dnia.
