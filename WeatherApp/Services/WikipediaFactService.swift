//
//  WikipediaFactService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import Foundation

// MARK: - wikipedia'nın "özet" servisinin ham cevabı
// vikipedi bu isteği için anahtar/kayıt gerektirmeyen, ücretsiz bir rest api
// sunuyor. tek bir sayfanın kısa özetini, varsa küçük bir resmiyle beraber
// veriyor
private nonisolated struct WikipediaSummaryResponse: Codable {
    let title: String
    let extract: String
    let type: String?
    let thumbnail: Thumbnail?

    struct Thumbnail: Codable { let source: String }
}

// MARK: - şehrin "ilginç bilgi"sini çeken servis
// hiçbir api anahtarı gerekmiyor. önce türkçe vikipedi'de arıyorum, orada
// yoksa (küçük yerleşimlerin çoğu türkçe'de yazılmamış olabiliyor) i̇ngilizce
// vikipedi'yi deniyorum, o da yoksa ülkenin kendisini deniyorum. hiçbiri
// olmazsa nil dönüyorum, ekran tarafı bunu "bulunamadı" mesajına çeviriyor
nonisolated struct WikipediaFactService {
    func fetchFact(cityName: String, countryName: String?) async -> CityFact? {
        if let fact = await fetchSummary(title: cityName, language: "tr") { return fact }
        if let fact = await fetchSummary(title: cityName, language: "en") { return fact }
        if let countryName, !countryName.isEmpty {
            if let fact = await fetchSummary(title: countryName, language: "tr") { return fact }
        }
        return nil
    }

    private func fetchSummary(title: String, language: String) async -> CityFact? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")
        else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(WikipediaSummaryResponse.self, from: data),
              !decoded.extract.isEmpty,
              decoded.type != "disambiguation" // "bu isimde birden fazla sayfa var" durumu, tek bir konu değil
        else { return nil }

        return CityFact(
            title: decoded.title,
            extract: decoded.extract,
            thumbnailURL: decoded.thumbnail.flatMap { URL(string: $0.source) }
        )
    }
}
